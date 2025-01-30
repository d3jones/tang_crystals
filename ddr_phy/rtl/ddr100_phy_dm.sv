module ddr100_phy_dm(
    input           clk100m,
    input           clk400m,    // used for DQS sampling
    input           phy_rst,    // resets PHY

    // write data
    input           wdm_p0, wdm_p1,

    // DM
    output          dm
);

wire    int_o, int_oen;
logic [7:0] p_dm;
logic [3:0] p_dm_oe;

assign p_dm_oe = 0;

// write:
OSER8 ser(
    .D7(p_dm[7]),
    .D6(p_dm[6]),
    .D5(p_dm[5]),
    .D4(p_dm[4]),
    .D3(p_dm[3]),
    .D2(p_dm[2]),
    .D1(p_dm[1]),
    .D0(p_dm[0]),
    .TX3(p_dm_oe[3]),
    .TX2(p_dm_oe[2]),
    .TX1(p_dm_oe[1]),
    .TX0(p_dm_oe[0]),
    .FCLK(clk400m),
    .PCLK(clk100m),
    .RESET(phy_rst),
    .Q0(int_o),
    .Q1(int_oen)
);

logic   wdm_p1_q;

always @(posedge clk100m)
    wdm_p1_q <= wdm_p1;

assign p_dm[7:6] = {2{wdm_p1}};
assign p_dm[5:2] = {4{wdm_p0}};
assign p_dm[1:0] = {2{wdm_p1_q}};

OBUF pad(
    .I(int_o),
    .O(dm)
);

endmodule