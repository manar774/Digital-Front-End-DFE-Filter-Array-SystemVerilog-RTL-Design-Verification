`timescale 1ns / 1ps

module tb_fractional_decimator;

  // ======================================================
  // DUT Interface Signals
  // ======================================================
  reg clk;
  reg reset;               // active-high reset
  reg clk_enable;
  reg signed [15:0] dataIn;  // s16.15 input
  reg validIn;

  wire signed [15:0] dataOut; // s16.15 output
  wire validOut;
  wire ce_out;

  // ======================================================
  // DUT Instantiation
  // ======================================================
  FinalFractionalDecimator dut (
    .clk(clk),
    .reset(reset),
    .clk_enable(clk_enable),
    .dataIn(dataIn),
    .validIn(validIn),
    .ce_out(ce_out),
    .dataOut(dataOut),
    .validOut(validOut)
  );

  // ======================================================
  // Clock Generation: 9 MHz (111.111 ns period)
  // ======================================================
  initial clk = 0;
  always #55.555 clk = ~clk;

  // ======================================================
  // Parameters and File Handles
  // ======================================================
  localparam integer NUM_SAMPLES = 32768;

  reg signed [15:0] stim [0:NUM_SAMPLES-1];
  integer fid_in, fid_out;
  integer status, rdata;
  integer i, out_count;

  // ======================================================
  // Testbench Main
  // ======================================================
  initial begin
    clk_enable = 1;
    reset      = 0;
    dataIn     = 0;
    validIn    = 0;
    out_count  = 0;

    // -------------------------------------------
    // Load stimulus file
    // -------------------------------------------
    fid_in = $fopen("frac_stimulus.txt", "r");
    if (fid_in == 0) begin
      $display("ERROR: Cannot open frac_stimulus.txt");
      $finish;
    end

    for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
      status = $fscanf(fid_in, "%d\n", rdata);
      stim[i] = (status == 1) ? rdata : 0;
    end
    $fclose(fid_in);

    // -------------------------------------------
    // Open output file
    // -------------------------------------------
    fid_out = $fopen("rtl_out_frac.csv", "w");
    if (fid_out == 0) begin
      $display("ERROR: Cannot open rtl_out_frac.csv");
      $finish;
    end

    // -------------------------------------------
    // Reset sequence
    // -------------------------------------------
    repeat (10) @(posedge clk);
    reset = 1;
    @(posedge clk);

    // -------------------------------------------
    // Feed input samples and capture output
    // -------------------------------------------
    for (i = 0; i < NUM_SAMPLES + 5000; i = i + 1) begin
      @(posedge clk);

      // Drive input
      if (i < NUM_SAMPLES) begin
        dataIn  <= stim[i];
        validIn <= 1;
      end else begin
        dataIn  <= 0;
        validIn <= 0;
      end

      // Capture output
      if (validOut) begin
        $fdisplay(fid_out, "%0d", $signed(dataOut));
        out_count = out_count + 1;
      end
    end

    // -------------------------------------------
    // Finish
    // -------------------------------------------
    $fclose(fid_out);
    $display("Simulation complete. Captured %0d samples in rtl_out_frac.csv", out_count);
    $finish;
  end

endmodule
