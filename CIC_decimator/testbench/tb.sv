`timescale 1ns/1ps

module tb_finalCIC_with_assertions;

  localparam STIM_FILE = "cic_stimulus.txt";
  localparam OUT_FILE  = "cic_tb_out.txt";
  localparam R_VALUE   = 12'd8;
  localparam SKIP_RTL  = 6;   // number of initial RTL outputs to skip

  reg clk;
  reg reset_n;         // active-low reset
  reg clk_enable;
  reg signed [15:0] dataIn;
  reg validIn;
  reg [11:0] RIn;
  reg resetIn;
  wire ce_out;
  wire signed [15:0] dataOut;   // ✅ now 16-bit, not 32-bit
  wire validOut;

  integer stim_fh, out_fh;
  integer stim_val;
  integer in_count, out_count;
  integer out_seen;

  // Clock generation (100 MHz)
  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    reset_n    = 0;
    clk_enable = 0;
    validIn    = 0;
    dataIn     = 0;
    RIn        = R_VALUE;
    resetIn    = 0;
    in_count   = 0;
    out_count  = 0;
    out_seen   = 0;

    stim_fh = $fopen(STIM_FILE, "r");
    out_fh  = $fopen(OUT_FILE, "w");
    if (stim_fh == 0 || out_fh == 0) begin
      $display("File open error");
      $finish;
    end

    // Hold reset for a few cycles
    repeat (10) @(posedge clk);
    reset_n    = 1;
    clk_enable = 1;

    // Pulse sync reset for combs
    @(posedge clk);
    resetIn = 1;
    @(posedge clk);
    resetIn = 0;

    // Feed samples
    while (!$feof(stim_fh)) begin
      @(posedge clk);
      if ($fscanf(stim_fh, "%d\n", stim_val) == 1) begin
        dataIn  <= stim_val;
        validIn <= 1;
        in_count = in_count + 1;
      end
    end

    // Stop driving
    @(posedge clk);
    validIn <= 0;
    dataIn  <= 0;

    // Allow pipeline flush
    repeat (64) @(posedge clk);

    $display("TB done. in=%0d, out=%0d (written steady-state only)", in_count, out_count);
    $fclose(stim_fh);
    $fclose(out_fh);
    $finish;
  end

  // DUT instantiation (matches new 16-bit output)
  finalCIC_with_assertions dut (
    .clk       (clk),
    .reset_n   (reset_n),
    .clk_enable(clk_enable),
    .dataIn    (dataIn),
    .validIn   (validIn),
    .RIn       (RIn),
    .resetIn   (resetIn),
    .ce_out    (ce_out),
    .dataOut   (dataOut),   // ✅ 16-bit now
    .validOut  (validOut)
  );

  // Capture DUT outputs (skip warm-up)
  always @(posedge clk) begin
    if (reset_n && clk_enable && validOut) begin
      out_seen++;
      if (out_seen > SKIP_RTL) begin
        out_count++;
        $fwrite(out_fh, "%0d\n", dataOut);  // ✅ writes 16-bit values
      end
    end
  end

endmodule
