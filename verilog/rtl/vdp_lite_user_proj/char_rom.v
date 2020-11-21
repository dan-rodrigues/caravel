`default_nettype none

// Read only character set
// There is 64KByte writable memory in the original VDP but no room for that here
// A small OpenRAM block of single port RAM of 4/8KByte may have been used otherwise

module char_rom #(
    parameter FILENAME = "reduce.hex"
) (
    input clk,

    input [9:0] address,
    output reg [15:0] read_data
);
    reg [15:0] mem [0:1023];

    initial begin
        $readmemh(FILENAME, mem);
    end

    always @(posedge clk) begin
        read_data <= mem[address];
    end

endmodule
