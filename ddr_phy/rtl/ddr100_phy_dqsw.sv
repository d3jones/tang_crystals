module ddr100_phy_dqsw(
    input           clk100m,
    input           clk400m,    // used for DQS sampling
    input           phy_rst,    // resets PHY

    // control inputs
    input           write,
    input           burst8,

    // control outputs
    output          write_start,
    output          write_main,
    output          write_end,

    // DQS
    inout           dqs, dqs_n
);

wire    int_o, int_oen;
logic [7:0] p_dqs;
logic [3:0] p_dqs_oe;

// write:
OSER8 ser(
    .D7(p_dqs[7]),
    .D6(p_dqs[6]),
    .D5(p_dqs[5]),
    .D4(p_dqs[4]),
    .D3(p_dqs[3]),
    .D2(p_dqs[2]),
    .D1(p_dqs[1]),
    .D0(p_dqs[0]),
    .TX3(p_dqs_oe[3]),
    .TX2(p_dqs_oe[2]),
    .TX1(p_dqs_oe[1]),
    .TX0(p_dqs_oe[0]),
    .FCLK(clk400m),
    .PCLK(clk100m),
    .RESET(phy_rst),
    .Q0(int_o),
    .Q1(int_oen)
);

logic [10:1] write_q;

always @(posedge clk100m)
    if (phy_rst) begin
        write_q <= 0;
    end else begin
        write_q <= {write_q[9:1],write};
    end

wire    preamble_start = write_q[5];
wire    preamble_main = burst8 ? |write_q[9:6] : |write_q[7:6];
wire    preamble_end = burst8 ? write_q[10] : write_q[8];
assign  p_dqs = 8'b11110000;
assign  write_start = write_q[6];
assign  write_main = burst8 ? |write_q[9:7] : write_q[7];
assign  write_end = burst8 ? write_q[10] : write_q[8];

always @* begin
    if (preamble_start | preamble_main)
        p_dqs_oe[3:2] = 2'b00;
    else
        p_dqs_oe[3:2] = 2'b11;
    if (preamble_end | preamble_main)
        p_dqs_oe[1:0] = 2'b00;
    else
        p_dqs_oe[1:0] = 2'b11;
end

// pad:
wire    dqs_in;

ELVDS_IOBUF pad(
    .I(int_o),
    .O(dqs_in),
    .OEN(int_oen),
    .IO(dqs),
    .IOB(dqs_n)
);

endmodule