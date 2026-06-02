`timescale 1 ns / 1 ns

module castSection
          (gcOut_re,
           gcOut_im,
           dataOut_re,
           dataOut_im);

  input   signed [19:0] gcOut_re;  // sfix20_En15
  input   signed [19:0] gcOut_im;  // sfix20_En15
  output  signed [15:0] dataOut_re;  // sfix16_En15
  output  signed [15:0] dataOut_im;  // sfix16_En15

  // Choose SHIFT based on measured headroom.
  // Start with SHIFT=0; increase (1..4) if you observe clipping.
  localparam integer SHIFT = 0;

  // Extend to 32-bit for safe arithmetic
  wire signed [31:0] re_ext = {{12{gcOut_re[19]}}, gcOut_re};
  wire signed [31:0] im_ext = {{12{gcOut_im[19]}}, gcOut_im};

  // Round-to-nearest before right shift
  wire signed [31:0] re_round = (SHIFT > 0) ? (re_ext + (32'sd1 <<< (SHIFT-1))) : re_ext;
  wire signed [31:0] im_round = (SHIFT > 0) ? (im_ext + (32'sd1 <<< (SHIFT-1))) : im_ext;

  // Arithmetic shift
  wire signed [31:0] re_shift = (SHIFT > 0) ? (re_round >>> SHIFT) : re_round;
  wire signed [31:0] im_shift = (SHIFT > 0) ? (im_round >>> SHIFT) : im_round;

  // Saturate to 16-bit signed range
  wire signed [15:0] re_sat =
      (re_shift > 32'sd32767)   ? 16'sd32767  :
      (re_shift < -32'sd32768)  ? -16'sd32768 :
                                  re_shift[15:0];

  wire signed [15:0] im_sat =
      (im_shift > 32'sd32767)   ? 16'sd32767  :
      (im_shift < -32'sd32768)  ? -16'sd32768 :
                                  im_shift[15:0];

  assign dataOut_re = re_sat;
  assign dataOut_im = im_sat;

endmodule  // castSection
