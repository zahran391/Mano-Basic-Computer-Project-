module alu (
    input [15:0] ac_in,     // Accumulator current value
    input [15:0] dr_in,     // Data Register value
    input [7:0]  inpr_in,   // Input register value (for INP instruction)
    input [2:0]  alu_op,    // Control signals to select ALU operation
    input        e_in,      // Current Carry (E)
    
    output reg [15:0] ac_out,// Result to Accumulator
    output reg        e_out  // Next Carry (E)
);

    always @(*) begin
        // Default values to prevent latches
        ac_out = ac_in;
        e_out  = e_in;
        // مع كل حاله بنشوف التاثير على الخرجين الي عندي 
        case (alu_op)
            3'b000: 
            begin // AND: AC <- AC ^ DR
                ac_out = ac_in & dr_in;
                e_out  = e_in;
            end
            3'b001: 
            begin // ADD: AC <- AC + DR, E <- Cout
                {e_out, ac_out} = ac_in + dr_in + e_in;
            end
            3'b010: 
            begin // CMA: AC <- ~AC (Complement Accumulator)
                ac_out = ~ac_in;
                e_out  = e_in;
            end
            3'b011: 
            begin // CME: E <- ~E (Complement Carry)
                ac_out = ac_in;
                e_out  = ~e_in;
            end
            3'b100: 
            begin // CIR: Circular Right 
                {e_out, ac_out} = {ac_in[0], ac_in[15:1], e_in}; 
            end
            3'b101: 
            begin // CIL: Circular Left 
                {e_out, ac_out} = {ac_in[15], ac_in[14:0], e_in}; 
            end
            3'b110: 
            begin // INC: AC <- AC + 1
                {e_out, ac_out} = ac_in + 1;
            end
            default: 
            begin
                ac_out = ac_in;
                e_out  = e_in;
            end
        endcase
    end
endmodule