`timescale 1 ns / 1 ns

module fir_output_formatter (
    input  wire              clk,
    input  wire              reset_n,     // active-low reset
    input  wire              enb,         // clock enable
    input  wire signed [31:0] dataIn32,   // CIC output (sfix32_En15)
    input  wire              validIn,
    output reg  signed [15:0] dataOut16,  // final s16.15 output
    output reg               validOut
);

    // -------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------
    // Shift amount: how many bits to drop to go from 32-bit Q15 to 16-bit Q15.
    // Adjust if you normalize gain in gcSection. For pure cast, use shift=15.
    parameter SHIFT = 15;

    // -------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------
    reg signed [31:0] rounded;
    reg signed [31:0] sat_val;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            dataOut16 <= 16'sd0;
            validOut  <= 1'b0;
        end else if (enb) begin
            if (validIn) begin
                // -------------------------------------------------
                // Convergent rounding (tie-to-even)
                // -------------------------------------------------
                // Take guard + LSB bits for rounding decision
                // Shift-1 gives guard bit, then tie-to-even on LSB
                reg signed [31:0] pre;
                reg guard, lsb, round_up;

                pre      = dataIn32 >>> (SHIFT-1);
                guard    = pre[0];       // guard bit
                lsb      = (pre >>> 1)[0]; // LSB of result
                round_up = guard & lsb;  // tie-to-even

                rounded  = (pre >>> 1) + (round_up ? 1 : 0);

                // -------------------------------------------------
                // Saturation to 16-bit signed range
                // -------------------------------------------------
                if (rounded > 32'sd32767)
                    sat_val = 32'sd32767;
                else if (rounded < -32'sd32768)
                    sat_val = -32'sd32768;
                else
                    sat_val = rounded;

                dataOut16 <= sat_val[15:0];
                validOut  <= 1'b1;
            end else begin
                validOut  <= 1'b0;
            end
        end
    end

endmodule
