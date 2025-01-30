// DDR PHY for 100 MHz operation (200M transfers/sec, DLL off)
// for Gowin GW2A FPGA
module ddr100_phy(
    input           clk100m,
    input           clk400m,    // used for DQS sampling
    input           phy_rst,    // resets PHY

    // configuration inputs
    input           burst8,
    
    // control inputs to DRAM
    input           i_rst,
    input           i_cke,
    input           i_cs_n,
    input           i_ras,
    input           i_cas,
    input           i_we,
    input [2:0]     i_ba,
    input [12:0]    i_addr,
    // data inputs: must be provided using proper timing relationship
    input [31:0]    i_wdata,    // write data
    input [3:0]     i_wdm,      // write data mask

    // data outputs from DRAM
    output          o_rdready,  // read data burst valid
    output [31:0]   o_rdata,

    // connections to DRAM
    output          ddr_ck,
    output          ddr_ck_n,
    output          ddr_rst,
    output          ddr_cke,
    output          ddr_cs_n,
    output          ddr_ras,
    output          ddr_cas,
    output          ddr_we,
    output [2:0]    ddr_ba,
    output [12:0]   ddr_addr,
    inout [15:0]    ddr_dq,
    output [1:0]    ddr_dm,
    inout [1:0]     ddr_dqs, ddr_dqs_n
);

io_ser8_diff u_ck(.pclk(clk100m), .fclk(clk400m), .rst(phy_rst), .din(8'hF0), .io(ddr_ck), .io_n(ddr_ck_n));
io_ser8 u_rst(.pclk(clk100m), .fclk(clk400m), .rst(phy_rst), .din({8{i_rst}}), .io(ddr_rst));
io_ser8 u_cke(.pclk(clk100m), .fclk(clk400m), .rst(phy_rst), .din({8{i_cke}}), .io(ddr_cke));
io_ser8 u_cs_n(.pclk(clk100m), .fclk(clk400m), .rst(phy_rst), .din({8{i_cs_n}}), .io(ddr_cs_n));
io_ser8 u_ras(.pclk(clk100m), .fclk(clk400m), .rst(phy_rst), .din({8{i_ras}}), .io(ddr_ras));
io_ser8 u_cas(.pclk(clk100m), .fclk(clk400m), .rst(phy_rst), .din({8{i_cas}}), .io(ddr_cas));
io_ser8 u_we(.pclk(clk100m), .fclk(clk400m), .rst(phy_rst), .din({8{i_we}}), .io(ddr_we));

for (genvar i = 0; i < 3; i++) begin: BA 
    io_ser8 u_we(.pclk(clk100m), .fclk(clk400m), .rst(phy_rst), .din({8{i_ba[i]}}), .io(ddr_ba[i]));
end
for (genvar i = 0; i < 13; i++) begin: ADDR 
    io_ser8 u_addr(.pclk(clk100m), .fclk(clk400m), .rst(phy_rst), .din({8{i_addr[i]}}), .io(ddr_addr[i]));
end

wire        write = {i_cs_n,i_ras,i_cas,i_we} == 4'b0100;
wire        read = {i_cs_n,i_ras,i_cas,i_we} == 4'b0101;
wire [1:0]  write_start, write_main, write_end;
wire [11:0] rsel;
wire        rvalid;

assign o_rdready = rvalid;

ddr100_phy_dqs dqs_0(
    .dqs(ddr_dqs[0]),
    .dqs_n(ddr_dqs_n[0]),
    .write_start(write_start[0]),
    .write_main(write_main[0]),
    .write_end(write_end[0]),
    .*);

ddr100_phy_dqsw dqs_1(
    .dqs(ddr_dqs[1]),
    .dqs_n(ddr_dqs_n[1]),
    .write_start(write_start[1]),
    .write_main(write_main[1]),
    .write_end(write_end[1]),
    .*);

for (genvar i = 0; i < 8; i++) begin: DQ
    ddr100_phy_dq dq_lo(
        .write_start(write_start[0]), 
        .write_main(write_main[0]),
        .write_end(write_end[0]),
        .wdata_p0(i_wdata[i]),
        .wdata_p1(i_wdata[i+16]),
        .dq(ddr_dq[i]),
        .rdata_p0(o_rdata[i]),
        .rdata_p1(o_rdata[i+16]),
        .*
    );

    ddr100_phy_dq dq_hi(
        .write_start(write_start[1]), 
        .write_main(write_main[1]),
        .write_end(write_end[1]),
        .wdata_p0(i_wdata[i+8]),
        .wdata_p1(i_wdata[i+24]),
        .dq(ddr_dq[i+8]),
        .rdata_p0(o_rdata[i+8]),
        .rdata_p1(o_rdata[i+24]),
        .*
    );
end

ddr100_phy_dm dm_lo(
    .wdm_p0(i_wdm[0]),
    .wdm_p1(i_wdm[2]),
    .dm(ddr_dm[0]),
    .*
);

ddr100_phy_dm dm_hi(
    .wdm_p0(i_wdm[1]),
    .wdm_p1(i_wdm[3]),
    .dm(ddr_dm[1]),
    .*
);
endmodule