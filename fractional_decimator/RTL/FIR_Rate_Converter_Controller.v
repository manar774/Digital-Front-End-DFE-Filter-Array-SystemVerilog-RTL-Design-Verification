// Hierarchy Level: 2

module FIR_Rate_Converter_Controller
          (clk,
           reset,
           enb,
           dataValid,
           phase,
           phaseValid,
           ready);


  input   clk;
  input   reset;
  input   enb;
  input   dataValid;
  output  phase;  // ufix1
  output  phaseValid;
  output  ready;


  wire [1:0] nextInputCount;  // ufix2
  reg [1:0] inputCount;  // ufix2
  wire rdyToAdv;
  reg  outputCount;  // ufix1
  reg [1:0] inputCountTableOut;  // ufix2
  wire [1:0] InputControl_out2;  // ufix2
  reg  phaseTableOut;  // ufix1
  reg  phase_1;  // ufix1
  reg  phaseValid_1;


  always @(posedge clk)
    begin : inputCountReg_process
      if (reset == 1'b0) begin
        inputCount <= 2'b01;
      end
      else begin
        if (enb) begin
          inputCount <= nextInputCount;
        end
      end
    end

  // Count limited, Unsigned Counter
  //  initial value   = 0
  //  step value      = 1
  //  count to value  = 1
  always @(posedge clk)
    begin : OutCounter_process
      if (reset == 1'b0) begin
        outputCount <= 1'b0;
      end
      else begin
        if (enb && rdyToAdv) begin
          outputCount <=  ~ outputCount;
        end
      end
    end

  // number of input samples needed for each output
  always @(outputCount) begin
    case ( outputCount)
      1'b0 :
        begin
          inputCountTableOut = 2'b01;
        end
      1'b1 :
        begin
          inputCountTableOut = 2'b10;
        end
      default :
        begin
          inputCountTableOut = 2'b00;
        end
    endcase
  end

  // Input control counter combinatorial logic
  assign rdyToAdv = (inputCount == 2'b00) || ((inputCount == 2'b01) && (dataValid != 1'b0));
  assign InputControl_out2 = (rdyToAdv != 1'b0 ? inputCountTableOut :
              (dataValid != 1'b0 ? inputCount - 2'b01 :
              inputCount));
  assign ready = InputControl_out2 != 2'b00;
  assign nextInputCount = InputControl_out2;

  // polyphase index for each ouput
  always @(outputCount) begin
    case ( outputCount)
      1'b0 :
        begin
          phaseTableOut = 1'b0;
        end
      1'b1 :
        begin
          phaseTableOut = 1'b1;
        end
      default :
        begin
          phaseTableOut = 1'b0;
        end
    endcase
  end

  always @(posedge clk)
    begin : phaseReg_process
      if (reset == 1'b0) begin
        phase_1 <= 1'b0;
      end
      else begin
        if (enb && rdyToAdv) begin
          phase_1 <= phaseTableOut;
        end
      end
    end

  always @(posedge clk)
    begin : phaseValidReg_process
      if (reset == 1'b0) begin
        phaseValid_1 <= 1'b0;
      end
      else begin
        if (enb) begin
          phaseValid_1 <= rdyToAdv;
        end
      end
    end

  assign phase = phase_1;

  assign phaseValid = phaseValid_1;

endmodule  // FIR_Rate_Converter_Controller
