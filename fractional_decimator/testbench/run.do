vlib work
vlog   FIR_Rate_Converter_Controller.v dsphdl_FIRRateConverter.v FIR_Rate_Conversion_Filter.v  FinalFractionalDecimator.v tb.v   +cover -covercells
vsim -voptargs=+acc work.tb_fractional_decimator -cover
add wave *
run -all


