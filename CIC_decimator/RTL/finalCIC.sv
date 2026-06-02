`timescale 1 ns / 1 ns

module finalCIC_with_assertions
  ( input  clk,
    input  reset_n,          // active-low reset
    input  clk_enable,
    input  signed [15:0] dataIn,
    input  validIn,
    input  [11:0] RIn,       // requested decimation factor
    input  resetIn,
    output ce_out,
    output signed [15:0] dataOut,   // sfix16_En15 final
    output validOut );

  // -------------------------------------------------------------
  // Sanitize R to allowed set {1,2,4,8,16}
  // -------------------------------------------------------------
  function automatic [11:0] sanitize_R(input [11:0] R);
    case (R)
      12'd1, 12'd2, 12'd4, 12'd8, 12'd16: sanitize_R = R;
      default: sanitize_R = 12'd1; // fallback safe value
    endcase
  endfunction

  wire [11:0] R_eff = sanitize_R(RIn);

  // -------------------------------------------------------------
  // Assertions (simulation only)
  // -------------------------------------------------------------
  property p_R_power_of_two;
    @(posedge clk) disable iff (!reset_n)
      (validIn && clk_enable) |->
        (RIn==12'd1 || RIn==12'd2 || RIn==12'd4 ||
         RIn==12'd8 || RIn==12'd16);
  endproperty

  assert property (p_R_power_of_two)
    else $error("Invalid decimation factor R=%0d. Allowed values are {1,2,4,8,16}", RIn);

  // -------------------------------------------------------------
  // CIC instance (now 16-bit output)
  // -------------------------------------------------------------
  CICDecimation u_cic (
    .clk        (clk),
    .reset      (reset_n),     // CIC uses active-low reset convention in your generated code
    .enb        (clk_enable),
    .dataIn     (dataIn),
    .validIn    (validIn),
    .R          (R_eff),       // sanitized R
    .syncReset  (resetIn),
    .dataOut    (dataOut),     // 16-bit s16.15 out
    .validOut   (validOut)
  );

  assign ce_out = clk_enable;

endmodule
