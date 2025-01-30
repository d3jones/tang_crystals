`timescale 1ns / 1ps

module tb_ddr100_phy;
logic           clk100m;
logic           clk400m;    // used for DQS sampling
logic           phy_rst;    // resets PHY

// control inputs to DRAM
logic           i_rst;
logic           i_cke;
logic           i_cs_n;
logic           i_ras;
logic           i_cas;
logic           i_we;
logic [2:0]     i_ba;
logic [12:0]    i_addr;
// data inputs: must be provided using proper timing relationship
logic [31:0]    i_wdata;    // write data
logic [3:0]     i_wdm;      // write data mask

// data outputs from DRAM
logic           o_rdready;  // read data burst valid
logic  [31:0]   o_rdata;

// connections to DRAM
logic           ddr_ck;
logic           ddr_ck_n;
logic           ddr_rst;
logic           ddr_cke;
logic           ddr_cs_n;
logic           ddr_ras;
logic           ddr_cas;
logic           ddr_we;
logic  [2:0]    ddr_ba;
logic  [12:0]   ddr_addr;
wire  [15:0]    ddr_dq;
wire  [1:0]     ddr_dm;
wire  [1:0]     ddr_dqs, ddr_dqs_n;
wire            burst8 = 1;

GSR GSR(1'b1);

ddr100_phy dut(.*);

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

always #1250ps clk400m = (clk400m === 1'b0);

CLKDIV#(.GSREN("false"), .DIV_MODE("4")) u_div(
    .HCLKIN(clk400m),
    .RESETN(1'b1),
    .CALIB(1'b0),
    .CLKOUT(clk100m)
);

initial begin
    phy_rst = 1;
    i_cke = 0;
    i_rst = 1;
    i_ba = 0;
    i_addr = 0;
    nop();
    repeat (4) @(posedge clk100m);
    phy_rst <= 0;
    i_rst <= 0;
    #200us; // required for reset
    @(posedge clk100m);
    i_rst <= 1;
    #500us; // required for reset
    @(posedge clk100m);
    i_cke <= 1;
    repeat (40) @(posedge clk100m);
    zqcl();
    load_mr(2, 'h008);  // CWL=6
    load_mr(3, 'h000);
    load_mr(1, 'h045);  // DLL off
    load_mr(0, 'h420);  // DLL off, CL=6
    repeat (12) nop();  // tMOD
    activate(3'b000, 13'h012);
    nop();
    nop();
    write('h45);
    nop();
    nop();
    data_write(32'h01234567, 4'b0000);
    data_write(32'h89abcdef, 4'b0000);
    data_write(32'hfedcba98, 4'b0000);
    data_write(32'h76543210, 4'b0000);
    nop();
    nop();
    nop();
    nop();
    read('h40);
    nop();
    nop();
    nop();
    nop();
    nop();
    nop();
    nop();
    nop();
    precharge(0);
    nop();
    nop();
    $finish;
end

task nop();
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b1111;
    @(posedge clk100m);
endtask

task load_mr(input [2:0] r_ba, input [12:0] r_data);
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b0000;
    i_ba <= r_ba;
    i_addr <= r_data;
    @(posedge clk100m);
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b1111;
    repeat (3) @(posedge clk100m);
endtask

task activate(input [2:0] r_ba, input [12:0] r_addr);
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b0011;
    i_ba <= r_ba;
    i_addr <= r_addr;
    @(posedge clk100m);
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b1111;
    repeat (3) @(posedge clk100m);
endtask
    
task precharge(input [2:0] r_ba);
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b0010;
    i_ba <= r_ba;
    @(posedge clk100m);
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b1111;
    repeat (3) @(posedge clk100m);
endtask

task zqcl();
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b0110;
    i_addr <= 'h400;
    @(posedge clk100m);
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b1111;
    repeat (511) @(posedge clk100m);
endtask
    
task write(input [12:0] r_addr);
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b0100;
    i_addr <= 'h1000 | r_addr;
    @(posedge clk100m);
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b1111;
    repeat (3) @(posedge clk100m);
endtask

task read(input [12:0] r_addr);
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b0101;
    i_addr <= 'h1000 | r_addr;
    @(posedge clk100m);
    {i_cs_n,i_ras,i_cas,i_we} <= 4'b1111;
    repeat (3) @(posedge clk100m);
endtask

task data_write(input [31:0] r_data, input [3:0] r_be);
    i_wdata <= r_data;
    i_wdm <= r_be;
    @(posedge clk100m);
endtask

endmodule

