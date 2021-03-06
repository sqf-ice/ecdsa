vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/tld_ecdsa_package.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_baud_clock.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_nm_piso_register.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_nm_sipo_register.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_gf2m_squarer.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_gf2m_point_addition.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_gf2m_point_doubling.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_gf2m_point_multiplication.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_gf2m_interleaved_mult.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_gf2m_eea_inversion.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_gf2m_doubleadd_point_multiplication.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_gf2m_divider.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_uart_receiver.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_uart_receive_mux.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_uart_transmit.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_uart_transmit_mux.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/e_ecdsa.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/src/tld_ecdsa.vhd
vcom -reportprogress 300 -work work C:/git/fhw/ecdsa/tests/tb_tld.vhd


vsim -voptargs=+acc work.tb_tld(tb_arch)

add wave sim:/tb_tld/tld_inst/*
add wave -divider "mux"
add wave sim:/tb_tld/tld_inst/uart_transmit/*
add wave -divider "transmitter"
add wave sim:/tb_tld/tld_inst/uart_transmit/transmit_instance/*
