`timescale 1ns/1ps
module tb_ddr_psram;
logic           clk100m;
logic           clk400m;    // used for DQS sampling
logic           phy_rst;    // resets PHY

// user interface
logic [26:2]    ps_addr;
logic           ps_re;      // enable to read, active high
logic           ps_we;      // enable to write
logic           ps_refresh; // suggest refresh
logic [31:0]    ps_wdata;
logic [3:0]     ps_wbe;     // byte enables, active high
logic           ps_cmdready;
logic  [31:0]   ps_rdata;
logic           ps_rdready;

// connections to DRAM
wire            ddr_ck;
wire            ddr_ck_n;
wire            ddr_rst;
wire            ddr_cke;
wire            ddr_cs_n;
wire            ddr_ras;
wire            ddr_cas;
wire            ddr_we;
wire   [2:0]    ddr_ba;
wire   [12:0]   ddr_addr;
wire  [15:0]    ddr_dq;
wire   [1:0]    ddr_dm;
wire  [1:0]     ddr_dqs, ddr_dqs_n;

GSR GSR(1'b1);

ddr100_psram dut(.*);

ddr3 mem(
    .ck(ddr_ck),
    .ck_n(ddr_ck_n),
    .rst_n(ddr_rst),
    .cke(ddr_cke),
    .cs_n(ddr_cs_n),
    .ras_n(ddr_ras),
    .cas_n(ddr_cas),
    .we_n(ddr_we),
    .ba(ddr_ba),
    .addr(ddr_addr),
    .dq(ddr_dq),
    .dm_tdqs(ddr_dm),
    .dqs(ddr_dqs),
    .dqs_n(ddr_dqs_n),
    .odt(1'b0)
);

always #1.25ns clk400m = (clk400m === 1'b0);
always #5ns    clk100m = (clk100m === 1'b0);
    
logic [31:0]    rdata;

initial begin
    phy_rst = 1;
    repeat (4) @(posedge clk100m);
    phy_rst <= 0;
    ps_we <= 0;
    ps_re <= 0;
    ps_refresh <= 1;
    fork
        begin
            write(32'h123457, 32'hA90D20D2, 4'b1111);
            read(32'h123457, rdata);
            repeat (20) @(posedge clk100m);
        end
        #1ms;
    join_any
    $finish;
end

task write(bit [26:2] addr, bit [31:0] data, bit [3:0] be);
    ps_we <= 1;
    ps_addr <= addr;
    ps_wdata <= data;
    ps_wbe <= be;
    @(posedge clk100m);
    while (!ps_cmdready) @(posedge clk100m);
    ps_we <= 0;
endtask

task read(bit [26:2] addr, output bit [31:0] data);
    ps_re <= 1;
    ps_addr <= addr;
    @(posedge clk100m);
    while (!ps_cmdready) @(posedge clk100m);
    ps_re <= 0;
    while (!ps_rdready) @(posedge clk100m);
    data = ps_rdata;
endtask

endmodule