module ddr100_phy_dq(
    input           clk100m,
    input           clk400m,    // used for DQS sampling
    input           phy_rst,    // resets PHY

    // control inputs
    input           write_start,
    input           write_main,
    input           write_end,

    // write data
    input           wdata_p0, wdata_p1,

    // interface to read subsystem
    input [11:0]    rsel,

    // read outputs
    output          rdata_p0, rdata_p1,

    // DQ
    inout           dq
);

wire    int_o, int_oen;
logic [7:0] p_dq;
logic [3:0] p_dq_oe;

// write:
OSER8 ser(
    .D7(p_dq[7]),
    .D6(p_dq[6]),
    .D5(p_dq[5]),
    .D4(p_dq[4]),
    .D3(p_dq[3]),
    .D2(p_dq[2]),
    .D1(p_dq[1]),
    .D0(p_dq[0]),
    .TX3(p_dq_oe[3]),
    .TX2(p_dq_oe[2]),
    .TX1(p_dq_oe[1]),
    .TX0(p_dq_oe[0]),
    .FCLK(clk400m),
    .PCLK(clk100m),
    .RESET(phy_rst),
    .Q0(int_o),
    .Q1(int_oen)
);

logic   wdata_p1_q;

always @(posedge clk100m)
    wdata_p1_q <= wdata_p1;

always @* begin
    if (write_start | write_main)
        p_dq_oe[3:1] = 3'b000;
    else
        p_dq_oe[3:1] = 3'b111;
    if (write_end | write_main)
        p_dq_oe[0] = 1'b0;
    else
        p_dq_oe[0] = 1'b1;
end

assign p_dq[7:6] = {2{wdata_p1}};
assign p_dq[5:2] = {4{wdata_p0}};
assign p_dq[1:0] = {2{wdata_p1_q}};

wire        dq_in;

IOBUF pad(
    .I(int_o),
    .OEN(int_oen),
    .IO(dq),
    .O(dq_in)
);

// read:
wire [7:0]  p_dq_in;

IDES8 des(
    .D(dq_in),
    .FCLK(clk400m),
    .PCLK(clk100m),
    .CALIB(1'b0),
    .RESET(phy_rst),
    .Q0(p_dq_in[0]),
    .Q1(p_dq_in[1]),
    .Q2(p_dq_in[2]),
    .Q3(p_dq_in[3]),
    .Q4(p_dq_in[4]),
    .Q5(p_dq_in[5]),
    .Q6(p_dq_in[6]),
    .Q7(p_dq_in[7])
);

reg [7:0]   p_dq_in_q1, p_dq_in_q2;

always @(posedge clk100m) begin
    p_dq_in_q1 <= p_dq_in;
    p_dq_in_q2 <= p_dq_in_q1;
end

wire [23:0] p_dq_in_window = {p_dq_in_q2,p_dq_in_q1,p_dq_in};

assign rdata_p1 = |(p_dq_in_window[18:7] & rsel);
assign rdata_p0 = |(p_dq_in_window[14:3] & rsel);

endmodule