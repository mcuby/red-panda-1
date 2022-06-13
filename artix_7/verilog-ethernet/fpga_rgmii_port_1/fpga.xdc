# XDC constraints for the Red Panda-1B
# part: xc7a50tcsg325-1

# General configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]

# System clocks
# 100 MHz clock
set_property -dict {LOC N3 IOSTANDARD SSTL15} [get_ports clk]
create_clock -period 10.000 -name clk [get_ports clk]

# UART
set_property -dict {LOC D13  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports uart_txd]
set_property -dict {LOC C12  IOSTANDARD LVCMOS33} [get_ports uart_rxd]

# Gigabit Ethernet GMII PHY

set_property -dict {LOC U16  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 16} [get_ports {phy_txd[0]}]
set_property -dict {LOC V16  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 16} [get_ports {phy_txd[1]}]
set_property -dict {LOC U15  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 16} [get_ports {phy_txd[2]}]
set_property -dict {LOC U14  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 16} [get_ports {phy_txd[3]}]

set_property -dict {LOC V11  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[0]}]
set_property -dict {LOC U11  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[1]}]
set_property -dict {LOC V12  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[2]}]
set_property -dict {LOC U12  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[3]}]

set_property -dict {LOC P15  IOSTANDARD LVCMOS18} [get_ports phy_rx_clk]
set_property -dict {LOC V14  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 16} [get_ports phy_tx_clk]

set_property -dict {LOC V13  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 16} [get_ports phy_tx_ctl]
set_property -dict {LOC U10  IOSTANDARD LVCMOS18} [get_ports phy_rx_ctl]

set_property -dict {LOC G17  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports phy_reset_n]
set_property -dict {LOC F18  IOSTANDARD LVCMOS33} [get_ports phy_int_n]

#set_property -dict {LOC V9  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports phy_mdio]
#set_property -dict {LOC U9  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports phy_mdc]

create_clock -period 8.000 -name phy_rx_clk [get_ports phy_rx_clk]

set_false_path -to [get_ports {phy_reset_n}]
set_output_delay 0 [get_ports {phy_reset_n}]
set_false_path -from [get_ports {phy_int_n}]
set_input_delay 0 [get_ports {phy_int_n}]

#set_false_path -to [get_ports {phy_mdio phy_mdc}]
#set_output_delay 0 [get_ports {phy_mdio phy_mdc}]
#set_false_path -from [get_ports {phy_mdio}]
#set_input_delay 0 [get_ports {phy_mdio}]
