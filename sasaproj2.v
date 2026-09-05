module ram_memory (
    input clk,
    input rstn,           // Active-Low Reset
    input cs,             // Chip Select
    input read,           // Read control signal
    input write,          // Write control signal
    input [11:0] addr,    // Address from AR (12 bits for 4096 words)
    input [15:0] data_in, // Data coming from the Bus (for write operations)
    output [15:0] data_out // Data going out to the Common Bus
);

    // 4096 words of 16 bits each width 16 for one word and depth of 4096 number of words
    reg [15:0] mem [0:4095];

    // 1. Asynchronous/Combinational Read (Directly to Bus)
    assign data_out = (cs && read) ? mem[addr] : 16'bz; // z for high-impedance state when not reading

    // 2. ASynchronous Write Operation
    always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) begin
            // Reset logic if needed
        end
         else if (cs && write) 
         begin
            mem[addr] <= data_in; 
        end
    end

endmodule