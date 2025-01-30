module io_ser8_diff(
    input       pclk,   // slow clock
    input       fclk,   // 4x slow clock
    input       rst,    // async reset
    input [7:0] din,
    output      io, io_n
);

wire    int_o;

OSER8 ser(
    .D7(din[7]),
    .D6(din[6]),
    .D5(din[5]),
    .D4(din[4]),
    .D3(din[3]),
    .D2(din[2]),
    .D1(din[1]),
    .D0(din[0]),
    .TX3(1'b0),
    .TX2(1'b0),
    .TX1(1'b0),
    .TX0(1'b0),
    .FCLK(fclk),
    .PCLK(pclk),
    .RESET(rst),
    .Q0(int_o),
    .Q1(int_oe)
);

ELVDS_OBUF pad(
    .I(int_o),
    .O(io),
    .OB(io_n)
);

endmodule