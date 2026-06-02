`timescale 1 ns / 1 ns

module CICDecimation
          (clk,
           reset,
           enb,
           dataIn,
           validIn,
           R,
           syncReset,
           dataOut,
           validOut);

  input   clk;
  input   reset;         // active-low in your file (reset==0 clears)
  input   enb;
  input   signed [15:0] dataIn;    // sfix16_En15
  input   validIn;
  input   [11:0] R;                // ufix12
  input   syncReset;
  output  signed [15:0] dataOut;   // sfix16_En15 (final)
  output  validOut;

  // Delay/register plumbing
  reg signed [15:0] intdelay_reg [0:1];  // sfix16 [2]
  wire signed [15:0] intdelay_reg_next [0:1];  // sfix16_En15 [2]
  wire signed [15:0] dataInreg;  // sfix16_En15
  reg  [1:0] intdelay_reg_1;  // ufix1 [2]
  wire validInreg;
  reg [11:0] calcDownSampleFactor_downsampleMax;  // ufix12
  reg  calcDownSampleFactor_vResetreg;
  reg  calcDownSampleFactor_enbV;
  wire [11:0] calcDownSampleFactor_downsampleMax_next;  // ufix12
  wire calcDownSampleFactor_vResetreg_next;
  wire [11:0] calcDownSampleFactor_downsampleIn;  // ufix12
  wire [11:0] downsampleVal;  // ufix12
  wire vReset;
  wire internalReset;

  // Data path between sections (unchanged widths)
  wire signed [19:0] integOut_re;  // sfix20_En15
  wire signed [19:0] integOut_im;  // sfix20_En15
  wire signed [19:0] dsOut_re;     // sfix20_En15
  wire signed [19:0] dsOut_im;     // sfix20_En15
  wire               ds_vout;
  wire signed [19:0] combOut_re;   // sfix20_En15
  wire signed [19:0] combOut_im;   // sfix20_En15
  wire               c_vout;

  // Final 16-bit cast outputs
  wire signed [15:0] dataOut_re;
  wire signed [15:0] dataOut_im;

  // 16-bit invalid (gated when not valid)
  wire signed [15:0] invalidOut_1 = 16'sd0;

  // ------------------ pipeline ------------------
  integer intdelay_t_0_0;
  integer intdelay_t_1;

  always @(posedge clk)
    begin : intdelay_process
      if (reset == 1'b0) begin
        for(intdelay_t_1 = 32'sd0; intdelay_t_1 <= 32'sd1; intdelay_t_1 = intdelay_t_1 + 32'sd1) begin
          intdelay_reg[intdelay_t_1] <= 16'sb0000000000000000;
        end
      end
      else begin
        if (enb) begin
          if (syncReset == 1'b1) begin
            for(intdelay_t_1 = 32'sd0; intdelay_t_1 <= 32'sd1; intdelay_t_1 = intdelay_t_1 + 32'sd1) begin
              intdelay_reg[intdelay_t_1] <= 16'sb0000000000000000;
            end
          end
          else begin
            for(intdelay_t_0_0 = 32'sd0; intdelay_t_0_0 <= 32'sd1; intdelay_t_0_0 = intdelay_t_0_0 + 32'sd1) begin
              intdelay_reg[intdelay_t_0_0] <= intdelay_reg_next[intdelay_t_0_0];
            end
          end
        end
      end
    end

  assign dataInreg = intdelay_reg[1];
  assign intdelay_reg_next[0] = dataIn;
  assign intdelay_reg_next[1] = intdelay_reg[0];

  always @(posedge clk)
    begin : intdelay_1_process
      if (reset == 1'b0) begin
        intdelay_reg_1 <= {2{1'b0}};
      end
      else begin
        if (enb) begin
          if (syncReset == 1'b1) begin
            intdelay_reg_1 <= {2{1'b0}};
          end
          else begin
            intdelay_reg_1[0] <= validIn;
            intdelay_reg_1[1] <= intdelay_reg_1[0];
          end
        end
      end
    end

  assign validInreg = intdelay_reg_1[1];

  // Downsample control (unchanged)
  always @(posedge clk)
    begin : calcDownSampleFactor_process
      if (reset == 1'b0) begin
        calcDownSampleFactor_downsampleMax <= 12'b000000000001;
        calcDownSampleFactor_vResetreg <= 1'b0;
        calcDownSampleFactor_enbV <= 1'b0;
      end
      else begin
        if (enb) begin
          if (syncReset == 1'b1) begin
            calcDownSampleFactor_downsampleMax <= 12'b000000000001;
            calcDownSampleFactor_vResetreg <= 1'b0;
            calcDownSampleFactor_enbV <= 1'b0;
          end
          else begin
            calcDownSampleFactor_downsampleMax <= calcDownSampleFactor_downsampleMax_next;
            calcDownSampleFactor_vResetreg <= calcDownSampleFactor_vResetreg_next;
            if (validIn != 1'b0) begin
              calcDownSampleFactor_enbV <= 1'b1;
            end
          end
        end
      end
    end

  assign calcDownSampleFactor_downsampleIn =
      ((R < 12'b000000000001) && (validIn != 1'b0)) ? 12'b000000000001 :
      ((R > 12'b000000010000) && (validIn != 1'b0)) ? 12'b000000010000 :
      R;

  assign calcDownSampleFactor_downsampleMax_next =
      ((calcDownSampleFactor_downsampleIn != calcDownSampleFactor_downsampleMax) && (validIn != 1'b0))
      ? calcDownSampleFactor_downsampleIn
      : calcDownSampleFactor_downsampleMax;

  assign calcDownSampleFactor_vResetreg_next =
      ((calcDownSampleFactor_downsampleIn != calcDownSampleFactor_downsampleMax) && (validIn != 1'b0))
      ? calcDownSampleFactor_enbV
      : 1'b0;

  assign downsampleVal = calcDownSampleFactor_downsampleMax;
  assign vReset        = calcDownSampleFactor_vResetreg;
  assign internalReset = syncReset | vReset;

  // Sections (unchanged)
  iSection u_iSection (
    .clk(clk), .reset(reset), .enb(enb),
    .dataInreg(dataInreg), .validInreg(validInreg),
    .internalReset(internalReset),
    .integOut_re(integOut_re), .integOut_im(integOut_im)
  );

  dsSection u_dsSection (
    .clk(clk), .reset(reset), .enb(enb),
    .integOut_re(integOut_re), .integOut_im(integOut_im),
    .validInreg(validInreg), .downsampleVal(downsampleVal),
    .i_rstout(internalReset),
    .dsOut_re(dsOut_re), .dsOut_im(dsOut_im),
    .ds_vout(ds_vout)
  );

  cSection u_cSection (
    .clk(clk), .reset(reset), .enb(enb),
    .dsOut_re(dsOut_re), .dsOut_im(dsOut_im),
    .ds_vout(ds_vout), .internalReset(internalReset),
    .combOut_re(combOut_re), .combOut_im(combOut_im),
    .c_vout(c_vout)
  );

  // Updated castSection generates final 16-bit outputs with rounding & saturation
  castSection u_castSection (
    .gcOut_re(combOut_re), .gcOut_im(combOut_im),
    .dataOut_re(dataOut_re), .dataOut_im(dataOut_im)
  );

  // Output gating on c_vout (unchanged timing)
  assign dataOut  = (c_vout == 1'b0) ? invalidOut_1 : dataOut_re;
  assign validOut = c_vout;

endmodule  // CICDecimation
