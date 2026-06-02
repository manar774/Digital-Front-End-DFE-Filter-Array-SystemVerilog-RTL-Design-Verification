vlib work
vlog cSection.v gcSection.v iSection.v dsSection.v castSection.v CICDecimation.v finalCIC.sv tb.sv   +cover -covercells
vsim -voptargs=+acc work.tb_finalCIC_with_assertions -cover
add wave *
run -all


