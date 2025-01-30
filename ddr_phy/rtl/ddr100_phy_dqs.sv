module ddr100_phy_dqs(
    input           clk100m,
    input           clk400m,    // used for DQS sampling
    input           phy_rst,    // resets PHY

    // control inputs
    input           read, write,
    input           burst8,

    // control outputs
    output          write_start,
    output          write_main,
    output          write_end,

    // interface to read subsystem
    output reg [11:0] rsel,
    output          rvalid,

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
logic [11:1] read_q;

always @(posedge clk100m)
    if (phy_rst) begin
        write_q <= 0;
        read_q <= 0;
    end else begin
        write_q <= {write_q[9:1],write};
        read_q <= {read_q[10:1],read};
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

// read:
wire [7:0]  p_dqs_in;

IDES8 des(
    .D(dqs_in),
    .FCLK(clk400m),
    .PCLK(clk100m),
    .CALIB(1'b0),
    .RESET(phy_rst),
    .Q0(p_dqs_in[0]),
    .Q1(p_dqs_in[1]),
    .Q2(p_dqs_in[2]),
    .Q3(p_dqs_in[3]),
    .Q4(p_dqs_in[4]),
    .Q5(p_dqs_in[5]),
    .Q6(p_dqs_in[6]),
    .Q7(p_dqs_in[7])
);

reg [7:0]   p_dqs_in_q1, p_dqs_in_q2;

always @(posedge clk100m) begin
    p_dqs_in_q1 <= p_dqs_in;
    p_dqs_in_q2 <= p_dqs_in_q1;
end

wire [23:0] p_dqs_in_window = {p_dqs_in_q2,p_dqs_in_q1,p_dqs_in};
wire [7:0]  rsel_in;

assign rsel_in[7] = &p_dqs_in_window[23:21] & ~|p_dqs_in_window[19:17] & ~|p_dqs_in_window[15:13];
assign rsel_in[6] = &p_dqs_in_window[22:20] & ~|p_dqs_in_window[18:16] & ~|p_dqs_in_window[14:12];
assign rsel_in[5] = &p_dqs_in_window[21:19] & ~|p_dqs_in_window[17:15] & ~|p_dqs_in_window[13:11];
assign rsel_in[4] = &p_dqs_in_window[20:18] & ~|p_dqs_in_window[16:14] & ~|p_dqs_in_window[12:10];
assign rsel_in[3] = &p_dqs_in_window[19:17] & ~|p_dqs_in_window[15:13] & ~|p_dqs_in_window[11: 9];
assign rsel_in[2] = &p_dqs_in_window[18:16] & ~|p_dqs_in_window[14:12] & ~|p_dqs_in_window[10: 8];
assign rsel_in[1] = &p_dqs_in_window[17:15] & ~|p_dqs_in_window[13:11] & ~|p_dqs_in_window[ 9: 7];
assign rsel_in[0] = &p_dqs_in_window[16:14] & ~|p_dqs_in_window[12:10] & ~|p_dqs_in_window[ 8: 6];

wire [7:0]  rsel_oh = rsel_in & ~{rsel_in[6:0],1'b0};
wire        defer = |rsel_oh[7:4];
wire [11:0] rsel_d = defer ? {4'b0,rsel_oh[3:0],rsel_oh[7:4]} : {rsel_oh,4'b0};

// Read valid state machine
wire        detect = |rsel_oh & |read_q[11:8];
reg [11:0]  rsel_q;

always @(posedge clk100m)
    if (phy_rst)
        rsel_q <= 0;
    else if (detect)
        rsel_q <= rsel_d;

assign      rsel = detect ? rsel_d : rsel_q;
        
// MXD can't do enums?
localparam [2:0] IDLE = 0;
localparam [2:0] DEFER = 1;
localparam [2:0] V1 = 2;
localparam [2:0] V2 = 3;
localparam [2:0] V3 = 4;
localparam [2:0] V4 = 5;

typedef logic [2:0] state_t;

/*
typedef enum logic [2:0] {
    IDLE,
    DEFER,
    V1,
    V2,
    V3,
    V4
} state_t;
*/

state_t state, next_state;

always @(posedge clk100m)
    if (phy_rst)
        state <= IDLE;
    else
        state <= next_state;

always @* begin
    next_state = state;
    case (state)
        IDLE:   if (detect) next_state <= defer ? DEFER : V1;
        DEFER:  next_state <= V1;
        V1:     next_state <= V2;
        V2:     next_state <= burst8 ? V3 : IDLE;
        V3:     next_state <= V4;
        V4:     next_state <= IDLE; // XXX: back-to-back reads ought to go to V1
    endcase
end

assign rvalid = state >= V1;

endmodule