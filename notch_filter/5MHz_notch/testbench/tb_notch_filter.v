`timescale 1ns/1ps

module tb_final_first_notch5;

  // Parameters (plain Verilog constants)
  localparam N_SAMPLES = 16384;
  localparam STIM_FILE = "notch5_stimulus.txt";
  localparam OUT_FILE  = "tb_out_final.txt";

  // DUT I/O signals
  reg clk;
  reg reset;          // active-low in generated RTL
  reg clk_enable;
  reg signed [15:0] dataIn;
  reg validIn;
  wire ce_out;
  wire signed [15:0] dataOut;
  wire validOut;

  // File handles and counters
  integer stim_fh, out_fh;
  integer stim_val;
  integer in_count, out_count;

  // Clock generation (100 MHz example)
  initial clk = 0;
  always #5 clk = ~clk;

  // Reset and stimulus
  initial begin
    reset      = 0;   // hold low (asserted)
    clk_enable = 0;
    validIn    = 0;
    dataIn     = 0;
    in_count   = 0;
    out_count  = 0;

    stim_fh = $fopen(STIM_FILE, "r");
    out_fh  = $fopen(OUT_FILE, "w");
    if (stim_fh == 0 || out_fh == 0) begin
      $display("File open error");
      $finish;
    end

    // Hold reset for a few cycles
    repeat (10) @(posedge clk);
    reset      = 1;   // deassert
    clk_enable = 1;

    // Feed samples
    while (!$feof(stim_fh)) begin
      @(posedge clk);
      $fscanf(stim_fh, "%d\n", stim_val);
      dataIn  <= stim_val;
      validIn <= 1;
      in_count = in_count + 1;
    end

    // Stop driving
    @(posedge clk);
    validIn <= 0;
    dataIn  <= 0;

    // Allow pipeline flush
    repeat (64) @(posedge clk);

    $display("TB done. in=%0d, out=%0d", in_count, out_count);
    $fclose(stim_fh);
    $fclose(out_fh);
    $finish;
  end

  // DUT instantiation
  Final20Notch5 dut (
    .clk       (clk),
    .reset     (reset),
    .clk_enable(clk_enable),
    .dataIn    (dataIn),
    .validIn   (validIn),
    .ce_out    (ce_out),
    .dataOut   (dataOut),
    .validOut  (validOut)
  );

  // Capture DUT outputs only (no comparison)
  always @(posedge clk) begin
    if (reset && clk_enable && validOut) begin
      out_count = out_count + 1;
      $fwrite(out_fh, "%0d\n", dataOut);
    end
  end

endmodule
