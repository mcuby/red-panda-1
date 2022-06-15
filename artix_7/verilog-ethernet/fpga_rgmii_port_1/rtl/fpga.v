/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * FPGA top-level module
 */
module fpga (
    /*
     * Clock: 100MHz
     * Reset: there isn't a reset button 
     */
    input  wire       clk,

    /*
     * Ethernet: 1000BASE-T RGMII
     */
    input  wire       phy_rx_clk,
    input  wire [3:0] phy_rxd,
    input  wire       phy_rx_ctl,
    output wire       phy_tx_clk,
    output wire [3:0] phy_txd,
    output wire       phy_tx_ctl,
    output wire       phy_reset_n,
    input  wire       phy_int_n,

    inout  wire       phy_mdio,
    output wire       phy_mdc,

    /*
     * UART: 500000 bps, 8N1
     */
    input  wire       uart_rxd,
    output wire       uart_txd
);

// Clock

wire clk_ibufg;

// Internal 125 MHz clock
wire clk_mmcm_out;
wire clk_int;
wire clk90_mmcm_out;
wire clk90_int;
wire clk_200mhz_mmcm_out;
wire clk_200mhz_int;

wire rst_int;
wire mmcm_rst = 1'b1;
wire mmcm_locked;
wire mmcm_clkfb;

IBUFG
clk_ibufg_inst(
    .I(clk),
    .O(clk_ibufg)
);

// MMCM instance
// input freq 100.0 Mhz
// clk_out1 125.0 MHz phase 0 divide 8.0 duty cycle 0.5
// clk_out2 125.0 MHz phase 90 divide 8 duty cycle 0.5
// clk_out3 200.0 Mhz phase 0 divide 5 duty cycle 0.5
// BANDWIDTH OPTIMIZED
// CLKFBOUT 10.0
// CLKFBOUT_PHASE 0.0
// CLKIN1_PERIOD 10.0
// CLKIN2_PERIOD 10.0
// DIVCLK_DIVIDE 1
// CLKFBOUT_MULT_F 10.0

MMCME2_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKOUT0_DIVIDE_F(8),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0),
    .CLKOUT1_DIVIDE(8),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE(90),
    .CLKOUT2_DIVIDE(5),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT2_PHASE(0),
    .CLKOUT3_DIVIDE(1),
    .CLKOUT3_DUTY_CYCLE(0.5),
    .CLKOUT3_PHASE(0),
    .CLKOUT4_DIVIDE(1),
    .CLKOUT4_DUTY_CYCLE(0.5),
    .CLKOUT4_PHASE(0),
    .CLKOUT5_DIVIDE(1),
    .CLKOUT5_DUTY_CYCLE(0.5),
    .CLKOUT5_PHASE(0),
    .CLKOUT6_DIVIDE(1),
    .CLKOUT6_DUTY_CYCLE(0.5),
    .CLKOUT6_PHASE(0),
    .CLKFBOUT_MULT_F(10),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(1),
    .REF_JITTER1(0.010),
    .CLKIN1_PERIOD(10.0),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
clk_mmcm_inst (
    .CLKIN1(clk_ibufg),
    .CLKFBIN(mmcm_clkfb),
    .RST(mmcm_rst),
    .PWRDWN(1'b0),
    .CLKOUT0(clk_mmcm_out),
    .CLKOUT0B(),
    .CLKOUT1(clk90_mmcm_out),
    .CLKOUT1B(),
    .CLKOUT2(clk_200mhz_mmcm_out),
    .CLKOUT2B(),
    .CLKOUT3(),
    .CLKOUT3B(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6(),
    .CLKFBOUT(mmcm_clkfb),
    .CLKFBOUTB(),
    .LOCKED(mmcm_locked)
);

BUFG
clk_bufg_inst (
    .I(clk_mmcm_out),
    .O(clk_int)
);

BUFG
clk90_bufg_inst (
    .I(clk90_mmcm_out),
    .O(clk90_int)
);

BUFG
clk_200mhz_bufg_inst (
    .I(clk_200mhz_mmcm_out),
    .O(clk_200mhz_int)
);

sync_reset #(
    .N(4)
)
sync_reset_inst (
    .clk(clk_int),
    .rst(~mmcm_locked),
    .out(rst_int)
);


reg [19:0] delay_reg = 20'hfffff;

reg [4:0] mdio_cmd_phy_addr = 5'h07;
reg [4:0] mdio_cmd_reg_addr = 5'h00;
reg [15:0] mdio_cmd_data = 16'd0;
reg [1:0] mdio_cmd_opcode = 2'b01;
reg mdio_cmd_valid = 1'b0;
wire mdio_cmd_ready;

reg [3:0] state_reg = 0;

//1 reg 4 = DE0 
//2 reg 4 = DE1 
//1 reg 9 = 300 
//2 reg 9 = 300 
//1 reg 16 = 0 
//2 reg 16 = 0 
//1 reg 10 = 7800 
//2 reg 10 = 7800 
//1 reg 0 = 1200 
//2 reg 0 = 1340 
//1 reg 0 = 8000 
//2 reg 0 = 9140

//XAxiEthernet_PhyWrite(xaxiemacp, phy_addr, 0x04, 0x0DE1);
//XAxiEthernet_PhyWrite(xaxiemacp, phy_addr, 0x09, 0x0300);
//XAxiEthernet_PhyWrite(xaxiemacp, phy_addr, 0x16, 0x0000);
//XAxiEthernet_PhyWrite(xaxiemacp, phy_addr, 0x10, 0x7800);
//XAxiEthernet_PhyWrite(xaxiemacp, phy_addr, 0x00, 0x1340);
//XAxiEthernet_PhyWrite(xaxiemacp, phy_addr, 0x00, 0x9140);

//sleep(5); 

always @(posedge clk_int) begin

        if (rst_int) begin
            state_reg <= 0;
            delay_reg <= 20'hfffff;
            mdio_cmd_reg_addr <= 5'h00;
            mdio_cmd_data <= 16'd0;
            mdio_cmd_valid <= 1'b0;
        end else begin
            mdio_cmd_valid <= mdio_cmd_valid & !mdio_cmd_ready;
            if (delay_reg > 0) begin
                delay_reg <= delay_reg - 1;
            end else if (!mdio_cmd_ready) begin
                // wait for ready
                state_reg <= state_reg;
            end else begin
                mdio_cmd_valid <= 1'b0;
                case (state_reg)
                    4'd0: begin
                        //reg 0x0 = 0x9140 
                        //mdio_cmd_reg_addr <= 5'h00;
                        //mdio_cmd_data <= 16'h9140;
                        //mdio_cmd_valid <= 1'b1;
                        state_reg <= 4'd1;
                    end
                    4'd1: begin
                        //reg 0x4 = 0xDE1
                        mdio_cmd_reg_addr <= 5'h04;
                        //mdio_cmd_data <= 16'h0DE0;
                        mdio_cmd_data <= 16'h0DE1;
                        mdio_cmd_valid <= 1'b1;
                        state_reg <= 4'd2;
                    end
                    4'd2: begin
                        //reg 0x9 = 0x300
                        mdio_cmd_reg_addr <= 5'h09;
                        mdio_cmd_data <= 16'h0300;
                        mdio_cmd_valid <= 1'b1;
                        state_reg <= 4'd3;
                    end
                    4'd3: begin
                        //reg 0x16 = 0x0
                        mdio_cmd_reg_addr <= 5'h16;
                        mdio_cmd_data <= 16'h0000;
                        mdio_cmd_valid <= 1'b1;
                        state_reg <= 4'd4;
                    end
                    4'd4: begin
                        //reg 0x10 = 0x7800
                        mdio_cmd_reg_addr <= 5'h10;
                        mdio_cmd_data <= 16'h7800;
                        mdio_cmd_valid <= 1'b1;
                        state_reg <= 4'd5;
                    end
                    4'd5: begin
                        //reg 0x0 = 0x1340
                        mdio_cmd_reg_addr <= 5'h00;
                        //mdio_cmd_data <= 16'h1200;
                        mdio_cmd_data <= 16'h1340;
                        mdio_cmd_valid <= 1'b1;
                        state_reg <= 4'd6;
                    end
                    4'd6: begin
                        //reg 0x0 = 0x9140
                        mdio_cmd_reg_addr <= 5'h00;
                        //mdio_cmd_data <= 16'h8000;
                        mdio_cmd_data <= 16'h9140;
                        mdio_cmd_valid <= 1'b1;
                        state_reg <= 4'd7;
                    end
                    4'd7: begin
                        // done
                        state_reg <= 4'd7;
                    end
                endcase
            end
     end
end

wire mdc;
wire mdio_i;
wire mdio_o;
wire mdio_t;

mdio_master
mdio_master_inst (
    .clk(clk_int),
    .rst(rst_int),

    .cmd_phy_addr(mdio_cmd_phy_addr),
    .cmd_reg_addr(mdio_cmd_reg_addr),
    .cmd_data(mdio_cmd_data),
    .cmd_opcode(mdio_cmd_opcode),
    .cmd_valid(mdio_cmd_valid),
    .cmd_ready(mdio_cmd_ready),

    .data_out(),
    .data_out_valid(),
    .data_out_ready(1'b1),

    .mdc_o(mdc),
    .mdio_i(mdio_i),
    .mdio_o(mdio_o),
    .mdio_t(mdio_t),

    .busy(),

    .prescale(8'd3)
);

assign phy_mdc = mdc;
assign mdio_i = phy_mdio;
assign phy_mdio = mdio_t ? 1'bz : mdio_o;


// IODELAY elements for RGMII interface to PHY
wire [3:0] phy_rxd_delay;
wire       phy_rx_ctl_delay;

IDELAYCTRL
idelayctrl_inst (
    .REFCLK(clk_200mhz_int),
    .RST(rst_int),
    .RDY()
);

IDELAYE2 #(
    .IDELAY_TYPE("FIXED")
)
phy_rxd_idelay_0 (
    .IDATAIN(phy_rxd[0]),
    .DATAOUT(phy_rxd_delay[0]),
    .DATAIN(1'b0),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'd0),
    .CNTVALUEOUT(),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

IDELAYE2 #(
    .IDELAY_TYPE("FIXED")
)
phy_rxd_idelay_1 (
    .IDATAIN(phy_rxd[1]),
    .DATAOUT(phy_rxd_delay[1]),
    .DATAIN(1'b0),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'd0),
    .CNTVALUEOUT(),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

IDELAYE2 #(
    .IDELAY_TYPE("FIXED")
)
phy_rxd_idelay_2 (
    .IDATAIN(phy_rxd[2]),
    .DATAOUT(phy_rxd_delay[2]),
    .DATAIN(1'b0),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'd0),
    .CNTVALUEOUT(),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

IDELAYE2 #(
    .IDELAY_TYPE("FIXED")
)
phy_rxd_idelay_3 (
    .IDATAIN(phy_rxd[3]),
    .DATAOUT(phy_rxd_delay[3]),
    .DATAIN(1'b0),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'd0),
    .CNTVALUEOUT(),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

IDELAYE2 #(
    .IDELAY_TYPE("FIXED")
)
phy_rx_ctl_idelay (
    .IDATAIN(phy_rx_ctl),
    .DATAOUT(phy_rx_ctl_delay),
    .DATAIN(1'b0),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'd0),
    .CNTVALUEOUT(),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);

// UART Rx
wire uart_rxd_int;

sync_signal #(
    .WIDTH(1),
    .N(2)
)
sync_signal_inst (
    .clk(clk_int),
    .in({uart_rxd}),
    .out({uart_rxd_int})
);

fpga_core #(
    .TARGET("XILINX")
)
core_inst (
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    .clk(clk_int),
    .clk90(clk90_int),
    .rst(rst_int),
    /*
     * Ethernet: 1000BASE-T RGMII
     */
    .phy_rx_clk(phy_rx_clk),
    .phy_rxd(phy_rxd_delay),
    .phy_rx_ctl(phy_rx_ctl_delay),
    .phy_tx_clk(phy_tx_clk),
    .phy_txd(phy_txd),
    .phy_tx_ctl(phy_tx_ctl),
    .phy_reset_n(phy_reset_n),
    .phy_int_n(phy_int_n),
    /*
     * UART: 115200 bps, 8N1
     */
    .uart_rxd(uart_rxd_int),
    .uart_txd(uart_txd)
);

endmodule

`resetall
