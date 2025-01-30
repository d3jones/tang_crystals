module ddr100_psram(
    input           clk100m,
    input           clk400m,    // used for DQS sampling
    input           phy_rst,    // resets PHY

    // user interface
    input [26:2]    ps_addr,
    input           ps_re,      // enable to read, active high
    input           ps_we,      // enable to write
    input           ps_refresh, // suggest refresh
    input [31:0]    ps_wdata,
    input [3:0]     ps_wbe,     // byte enables, active high
    output logic    ps_cmdready,
    output reg [31:0] ps_rdata,
    output reg      ps_rdready,

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

// PHY signals
logic           i_rst;
logic           i_cke;
logic           i_cs_n;
logic           i_ras;
logic           i_cas;
logic           i_we;
logic [2:0]     i_ba;
logic [12:0]    i_addr;
logic [31:0]    i_wdata;    // write data
logic [3:0]     i_wdm;      // write data mask

// data outputs from DRAM
wire            o_rdready;  // read data burst valid
wire   [31:0]   o_rdata;

ddr100_phy u_phy(
    .burst8(0),
    .*
);

// Timer - for various things
logic           tmr_reset;
logic [15:0]    tmr_count;

always @(posedge clk100m or posedge phy_rst)
    if (phy_rst)
        tmr_count <= 0;
    else if (tmr_reset)
        tmr_count <= 0;
    else
        tmr_count <= tmr_count + 1;

`ifdef FAST_SIM
localparam  FAST_SIM = 1;
`else
localparam  FAST_SIM = 0;
`endif

wire            tmr_eq_0 = ~|tmr_count;
wire            tmr_eq_4 = tmr_count[2];
wire            tmr_eq_5 = tmr_count[2] & tmr_count[0];
wire            tmr_eq_16 = tmr_count[4];
wire            tmr_eq_512 = tmr_count[9];
wire            tmr_eq_20k = FAST_SIM ? tmr_count[8] : tmr_count[14] & tmr_count[12];
wire            tmr_eq_50k = FAST_SIM ? tmr_count[8] : tmr_count[15] & tmr_count[14] & tmr_count[11];

// FSM
localparam [3:0]    ST_RESET = 0;
localparam [3:0]    ST_PRE_CKE = 1;
localparam [3:0]    ST_POST_CKE = 2;
localparam [3:0]    ST_ZQCL = 3;
localparam [3:0]    ST_MR2 = 4;
localparam [3:0]    ST_MR3 = 5;
localparam [3:0]    ST_MR1 = 6;
localparam [3:0]    ST_MR0 = 7;
localparam [3:0]    ST_READY = 8;
localparam [3:0]    ST_ACTIVATE = 9;
localparam [3:0]    ST_RW = 10;
localparam [3:0]    ST_REFRESH = 11;

logic [3:0]     state, next_state;
logic [26:2]    ps_addr_q;
logic [31:0]    ps_wdata_q;
logic           ps_we_q, ps_re_q, ps_refresh_q;
logic [3:0]     ps_wbe_q;
logic           write, read;

always @(posedge clk100m or posedge phy_rst)
    if (phy_rst) begin
        state <= ST_RESET;
        ps_cmdready <= 0;
        ps_addr_q <= 0;
        ps_wdata_q <= 0;
        ps_re_q <= 0;
        ps_we_q <= 0;
        ps_refresh_q <= 0;
        ps_wbe_q <= 0;
    end else begin
        state <= next_state;
        ps_cmdready <= (next_state == ST_READY);
        if (state == ST_READY) begin
            ps_addr_q <= ps_addr;
            ps_wdata_q <= ps_wdata;
            ps_re_q <= ps_re;
            ps_we_q <= ps_we;
            ps_refresh_q <= ps_refresh;
            ps_wbe_q <= ps_wbe;
        end
    end

assign i_wdata = ps_wdata_q;

always @* begin
    next_state = state;
    tmr_reset = 0;
    i_rst = 1;
    i_cke = 1;
    i_ba = 0;
    i_addr = 0;
    write = 0;
    read = 0;
    case (state)
    ST_RESET: begin
        i_rst = 0;
        i_cke = 0;
        {i_cs_n,i_ras,i_cas,i_we} = 4'b1111;
        if (tmr_eq_20k) begin
            next_state = ST_PRE_CKE;
            tmr_reset = 1;
        end
    end
    ST_PRE_CKE: begin
        i_rst = 1;
        i_cke = 0;
        {i_cs_n,i_ras,i_cas,i_we} = 4'b1111;
        if (tmr_eq_50k) begin
            next_state = ST_POST_CKE;
            tmr_reset = 1;
        end
    end
    ST_POST_CKE: begin
        {i_cs_n,i_ras,i_cas,i_we} = 4'b1111;
        if (tmr_eq_16) begin
            next_state = ST_ZQCL;
            tmr_reset = 1;
        end
    end
    ST_ZQCL: begin
        {i_cs_n,i_ras,i_cas,i_we} = (tmr_eq_0) ? 4'b0110 : 4'b1111;
        if (tmr_eq_512) begin
            next_state = ST_MR2;
            tmr_reset = 1;
        end
    end
    ST_MR2: begin
        {i_cs_n,i_ras,i_cas,i_we} = (tmr_eq_0) ? 4'b0000 : 4'b1111;
        i_ba = 3'b010;
        i_addr = 13'h8;
        if (tmr_eq_4) begin
            next_state = ST_MR3;
            tmr_reset = 1;
        end
    end
    ST_MR3:begin
        {i_cs_n,i_ras,i_cas,i_we} = (tmr_eq_0) ? 4'b0000 : 4'b1111;
        i_ba = 3'b011;
        i_addr = 13'h0;
        if (tmr_eq_4) begin
            next_state = ST_MR1;
            tmr_reset = 1;
        end
    end
    ST_MR1: begin
        {i_cs_n,i_ras,i_cas,i_we} = (tmr_eq_0) ? 4'b0000 : 4'b1111;
        i_ba = 3'b001;
        i_addr = 13'h45;
        if (tmr_eq_4) begin
            next_state = ST_MR0;
            tmr_reset = 1;
        end
    end
    ST_MR0: begin
        {i_cs_n,i_ras,i_cas,i_we} = (tmr_eq_0) ? 4'b0000 : 4'b1111;
        i_ba = 3'b000;
        i_addr = 13'h422;
        if (tmr_eq_16) begin
            next_state = ST_READY;
            tmr_reset = 1;
        end
    end
    ST_READY: begin
        {i_cs_n,i_ras,i_cas,i_we} = 4'b1111;
        if (ps_re || ps_we) begin
            next_state = ST_ACTIVATE;
            tmr_reset = 1;
        end
        // XXX: refresh 
    end

    ST_ACTIVATE: begin
        // Given addr[26:2]:
        // row:   [26:14]   13 bits
        // bank:  [13:11]    3 bits
        // column: [10:1]   10 bits
        {i_cs_n,i_ras,i_cas,i_we} = (tmr_eq_0) ? 4'b0011 : 4'b1111;
        i_ba = ps_addr_q[13:11];
        i_addr = ps_addr_q[26:14];
        if (tmr_eq_5) begin
            next_state = ST_RW;
            tmr_reset = 1;
        end
    end

    ST_RW: begin
        {i_cs_n,i_ras,i_cas,i_we} = (tmr_eq_0) ? {3'b010,ps_re_q} : 4'b1111;
        // For writes, DRAM will ignore A[2:1]. Must always write on 4-aligned boundary and use DM as required.
        // For reads, DRAM will provide word on A[2:1] first.
        // For PSRAM we always select auto-precharge.
        i_ba = ps_addr_q[13:11];
        write = ps_we_q & tmr_eq_0;
        read = ps_re_q & tmr_eq_0;
        i_addr = {1'b1,ps_addr_q[10:2],1'b0};
        if (tmr_eq_16) begin
            // XXX: can likely tighten this up. Also consider refresh.
            next_state = ST_READY;
            tmr_reset = 1;
        end
    end

    //ST_REFRESH: ;
    default: begin
        i_rst = 1;
        i_cke = 1;
    end
    endcase
end

// write control
logic [6:0]     write_q;

always @(posedge clk100m)
    if (phy_rst) begin
        i_wdm <= 4'b1111;
        write_q <= 0;
    end else begin
        write_q <= {write_q[5:0],write};
        if (write_q[4] & !ps_addr_q[2] | write_q[5] & ps_addr_q[2])
            i_wdm <= ~ps_wbe_q;
        else
            i_wdm <= 4'b1111;
    end
    
// read control 
logic           o_rdready_q;

always @(posedge clk100m)
    if (phy_rst) begin
        o_rdready_q <= 0;
        ps_rdready <= 0;
    end else begin
        o_rdready_q <= o_rdready;
        if (!o_rdready_q && o_rdready) begin
            ps_rdready <= 1;
            ps_rdata <= o_rdata;
        end else if (next_state == ST_ACTIVATE) begin
            ps_rdready <= 0;
        end
    end

endmodule
