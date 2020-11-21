`default_nettype none

module ffram #(
    parameter INIT_FILE = "",

    parameter integer DATA_WIDTH = 8,
    parameter integer ADDR_WIDTH = 8,

    parameter integer DW = DATA_WIDTH - 1,
    parameter integer AW = ADDR_WIDTH - 1

) (
    input clk,

    input [AW:0] addr0,
    input [DW:0] wdata0,
    output reg [DW:0] rdata0,
    input we0,

    input [AW:0] addr1,
    output reg [DW:0] rdata1
);
    localparam WORDS = (1 << ADDR_WIDTH) - 1;

    reg [DW:0] mem [0:WORDS];

    integer i;
    initial begin
        for (i = 0; i <= WORDS; i = i + 1) begin
            mem[i] = 0;
        end

        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    always @(posedge clk) begin
        if (we0) begin
            mem[addr0] <= wdata0;
        end

        rdata0 <= mem[addr0];
        rdata1 <= mem[addr1];
    end

endmodule
