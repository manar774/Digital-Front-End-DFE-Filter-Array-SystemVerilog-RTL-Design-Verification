// Hierarchy Level: 2

module FIR_Rate_Conversion_Filter
          (input  wire clk,
           input  wire reset,
           input  wire enb,
           input  wire signed [15:0] data,       // sfix16_En15
           input  wire dataValid,
           input  wire phase,                    // ufix1
           input  wire phaseValid,
           output wire signed [15:0] dataOut,    // sfix16_En15
           output wire validOut);

  // ---------------------------------------------------------
  // 1. PARAMETERS
  // ---------------------------------------------------------
  localparam NUM_TAPS = 72;
  
  // LATENCY CALCULATION:
  // 1 (Phase Latch) + 1 (Mult) + 7 (Adder Tree) + 1 (Output Reg) = 10 Cycles
  localparam PIPELINE_LATENCY = 10; 

  // ---------------------------------------------------------
  // 2. SIGNAL DECLARATIONS
  // ---------------------------------------------------------
  reg signed [19:0] coeff_table [0:NUM_TAPS-1][0:1]; ///

  // Pipeline Signals
  reg signed [15:0] tap_delay_line  [0:NUM_TAPS-1];
  
  // Phase Latches (Synchronized Data & Coeffs)
  reg signed [15:0] tap_latched     [0:NUM_TAPS-1];
  reg signed [19:0] coeff_latched   [0:NUM_TAPS-1]; ///
  
  // Multiplier Result
  reg signed [35:0] product_pipe    [0:NUM_TAPS-1]; ///
  
// --- Signal Declarations for Adder Tree ---
  reg signed [36:0] sum_stage_0 [0:35]; // 72 inputs -> 36 outputs
  reg signed [36:0] sum_stage_1 [0:17]; // 36 inputs -> 18 outputs
  reg signed [36:0] sum_stage_2 [0:8];  // 18 inputs -> 9 outputs
  reg signed [36:0] sum_stage_3 [0:4];  // 9 inputs  -> 5 outputs (4 sums + 1 pass)
  reg signed [36:0] sum_stage_4 [0:2];  // 5 inputs  -> 3 outputs (2 sums + 1 pass)
  reg signed [36:0] sum_stage_5 [0:1];  // 3 inputs  -> 2 outputs (1 sum + 1 pass)
  reg signed [36:0] sum_stage_6;        // 2 inputs  -> 1 output
  

  // Output Processing
  wire signed [36:0] sum_final_scaled; 
  reg  signed [15:0] dataOut_reg;
  reg  [PIPELINE_LATENCY-1:0] valid_pipeline;

  // ---------------------------------------------------------
  // 3. COEFFICIENT INITIALIZATION
  // ---------------------------------------------------------

    initial begin
        // This loads the hex values from the file into the array automatically
        $readmemh("coeffs.mem", coeff_table);
    end

// Ensure valid_pipeline is declared clearly
  // We need to tap into: 
  // [0] -> For Multiplier
  // [1] -> For Adder Stage 0
  // [2] -> For Adder Stage 1
  // [3] -> For Adder Stage 2
  // [4] -> For Adder Stage 3
  // [5] -> For Adder Stage 4
  // [6] -> For Output Register
  
  // ---------------------------------------------------------
  // 4. MAIN PIPELINE GENERATION
  // ---------------------------------------------------------
  genvar i;
  generate
    for (i = 0; i < NUM_TAPS; i = i + 1) begin : FILTER_CORE
      
      // --- A. Tap Delay Line (Data History) ---
      always @(posedge clk) begin
        if (reset == 1'b0) tap_delay_line[i] <= 0;
        else if (enb && dataValid) begin
          if (i == 0) tap_delay_line[i] <= data;
          else        tap_delay_line[i] <= tap_delay_line[i-1];
        end
      end

      // --- B. Phase Synchronization (The Critical Fix) ---
      // We latch BOTH the Coefficient and the Data Sample at the exact same moment.
      // This guarantees they belong to the same Phase.
      always @(posedge clk) begin
        if (reset == 1'b0) begin
           coeff_latched[i] <= 0;
           tap_latched[i]   <= 0;
        end else if (enb && phaseValid) begin
           coeff_latched[i] <= coeff_table[i][phase];
           tap_latched[i]   <= tap_delay_line[i];
        end
      end

      // --- C. Multiplication ---
      // Uses the perfectly aligned signals from above.
      always @(posedge clk) begin
        if (reset == 1'b0) product_pipe[i] <= 0;
        else if (enb && valid_pipeline[0]) begin
           product_pipe[i] <= tap_latched[i] * coeff_latched[i]; 
        end
      end
    end
  endgenerate

  // ---------------------------------------------------------
  // 5. ADDER TREE (32-bit)
  // ---------------------------------------------------------
  genvar k;
  generate
     
    // Stage 0: 72 inputs -> 36 outputs
    for (k = 0; k < 36; k = k + 1) begin : ADDER_STAGE_0
      always @(posedge clk) begin
        if (reset == 1'b0) sum_stage_0[k] <= 0;
        // POWER FIX: Only add if the Multiplier data is valid
        else if (enb && valid_pipeline[1]) sum_stage_0[k] <= product_pipe[2*k] + product_pipe[2*k+1];
      end
    end

    // Stage 1: 36 inputs ->18 outputs
    for (k = 0; k < 18; k = k + 1) begin : ADDER_STAGE_1
      always @(posedge clk) begin
        if (reset == 1'b0) sum_stage_1[k] <= 0;
        else if (enb && valid_pipeline[2]) sum_stage_1[k] <= sum_stage_0[2*k] + sum_stage_0[2*k+1];
      end
    end

    // Stage 2: 18 inputs -> 9 outputs
    for (k = 0; k < 9; k = k + 1) begin : ADDER_STAGE_2
      always @(posedge clk) begin
        if (reset == 1'b0) sum_stage_2[k] <= 0;
        else if (enb && valid_pipeline[3]) sum_stage_2[k] <= sum_stage_1[2*k] + sum_stage_1[2*k+1];
      end
    end

    // Stage 3: 9 inputs -> 5 outputs
    for (k = 0; k < 4; k = k + 1) begin : ADD_STAGE3_PAIRS
       always @(posedge clk) begin
         if (reset == 1'b0) sum_stage_3[k] <= 0;
         else if (enb && valid_pipeline[4]) 
            sum_stage_3[k] <= sum_stage_2[2*k] + sum_stage_2[2*k+1];
       end
    end   
    
    // Handle the leftover 9th element
    always @(posedge clk) begin 
        if (reset == 1'b0) sum_stage_3[4] <= 0; 
        else if (enb && valid_pipeline[4]) sum_stage_3[4] <= sum_stage_2[8]; 
    end
    
   // Stage 4: 5 -> 3
    for (k = 0; k < 2; k = k + 1) begin : ADD_STAGE4_PAIRS
       always @(posedge clk) begin
         if (reset == 1'b0) sum_stage_4[k] <= 0;
         else if (enb && valid_pipeline[5]) 
            sum_stage_4[k] <= sum_stage_3[2*k] + sum_stage_3[2*k+1];
       end
    end
    // Handle leftover 5th element
    always @(posedge clk) begin
         if (reset == 1'b0) sum_stage_4[2] <= 0;
         else if (enb && valid_pipeline[5]) sum_stage_4[2] <= sum_stage_3[4];
    end 
   
   // Stage 5: 3 -> 2 
    always @(posedge clk) begin : ADDER_STAGE_5
      if (reset == 1'b0) begin
        sum_stage_5[0] <= 0;
        sum_stage_5[1] <= 0;
      end else if (enb && valid_pipeline[6]) begin
        sum_stage_5[0] <= sum_stage_4[0] + sum_stage_4[1];
        sum_stage_5[1] <= sum_stage_4[2];
      end
    end

    // Stage 6: 2 inputs -> 1 output
    always @(posedge clk) begin : ADDER_STAGE_6
      if (reset == 1'b0) sum_stage_6 <= 0;
      else if (enb && valid_pipeline[7]) sum_stage_6 <= sum_stage_5[0] + sum_stage_5[1];
    end
  endgenerate

  // ---------------------------------------------------------
  // 6. OUTPUT SATURATION & SCALING
  // ---------------------------------------------------------
  assign sum_final_scaled = sum_stage_6 <<< 1;


wire signed [15:0] y_saturated;

// 1. Define readable constants for clarity
localparam signed [15:0] MAX_POS = 16'sb0111111111111111; //  0.999...
localparam signed [15:0] MAX_NEG = 16'sb1000000000000000; // -1.000...

// 2. Break down the status bits
wire sign_guard  = sum_final_scaled[36];     // The "true" sign bit (bit 36)
wire sign_target = sum_final_scaled[35];     // The sign bit of the target 16-bit slice
wire [15:0] raw_slice = sum_final_scaled[35:20]; // The unrounded 16-bit result

// 3. Define rounding bits
wire bit_lsb    = sum_final_scaled[20];       // The last bit we keep
wire bit_half   = sum_final_scaled[19];       // The "0.5" bit (first dropped bit)
wire bit_sticky = |sum_final_scaled[18:0];    // Are there any 1s in the lower bits?

// 4. Calculate logic flags
// Round to Nearest, Ties to Even logic
wire do_round_up = bit_half & (bit_lsb | bit_sticky);

// Logic: True Positive AND (Sign flipped OR Result is already MAX)
wire is_pos_overflow = (~sign_guard && sign_target) || 
                       (~sign_guard && (raw_slice == MAX_POS));

// Logic: True Negative AND Sign flipped
wire is_neg_overflow = (sign_guard && ~sign_target);

// 5. Final Assignment (Same structure as original)
assign y_saturated = (is_pos_overflow) ? MAX_POS :
           (is_neg_overflow) ? MAX_NEG :
           (raw_slice + {15'd0, do_round_up}); // Add 1 or 0

  // Final Output Register
  always @(posedge clk) begin
    if (reset == 1'b0) dataOut_reg <= 0;
    else if (enb && valid_pipeline[8]) dataOut_reg <= y_saturated;
  end

  assign dataOut = dataOut_reg;

  // ---------------------------------------------------------
  // 7. VALID SIGNAL ALIGNMENT
  // ---------------------------------------------------------
  always @(posedge clk) begin
    if (reset == 1'b0) valid_pipeline <= 0;
    else if (enb) begin
       // Latency = 10 Cycles
       valid_pipeline <= {valid_pipeline[PIPELINE_LATENCY-2:0], phaseValid};
    end
  end

  assign validOut = valid_pipeline[PIPELINE_LATENCY-1];

endmodule
