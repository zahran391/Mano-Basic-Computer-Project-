module mano_computer_top (
    input clk,
    input reset,
    input [15:0] in_port, // Data from Input Register (INPR)
    output [15:0] out_port // Data to Output Register (OUTR)
);

    // Internal Wires for Interconnections
    wire [15:0] bus_data;
    wire [2:0] sel;
    
    // Registers outputs and inputs
    wire [15:0] pc_out, ar_out, dr_out, ac_out, ir_out, tr_out;
    wire [15:0] ram_data_out;
    
    // Control Signals from Control Unit
    wire sc_clear;
    wire [3:0] sc;
    wire r_ff, ien_ff;
    wire ar_ld, ar_clr, ar_inr;
    wire pc_ld, pc_clr, pc_inr;
    wire dr_ld, dr_clr, dr_inr;
    wire ac_ld, ac_clr, ac_inr;
    wire ir_ld, ir_clr;
    wire tr_ld, tr_clr, tr_inr;
    wire ram_cs, ram_read, ram_write;
    wire [2:0] alu_op;
    wire e_ld, e_clr, e_inv;
    wire e_out;
    wire fgi, fgo; // Flags for I/O

    // Temporary signals for ALU and operations
    wire [15:0] alu_out;
    wire alu_cout;

    // 1) Common Bus
    // ربط الباص الرئيسي باختيار الـ Select signals (sel)
    // 000: None, 001: AR, 010: PC, 011: DR, 100: AC, 101: IR, 110: TR, 111: RAM
    assign bus_data = (sel == 3'b001) ? ar_out :
                      (sel == 3'b010) ? pc_out :
                      (sel == 3'b011) ? dr_out :
                      (sel == 3'b100) ? ac_out :
                      (sel == 3'b101) ? ir_out :
                      (sel == 3'b110) ? tr_out :
                      (sel == 3'b111) ? ram_data_out : 16'b0;

    // 2) Control Unit Module
    control_unit cu (
        .clk(clk),
        .reset(reset),
        .ir_in(ir_out),
        .dr_in(dr_out),
        .ac_in(ac_out),
        .e_in(e_out),
        .fgi(fgi),
        .fgo(fgo),
        .ien_in(ien_ff),
        .sc(sc),
        .r_ff(r_ff),
        .ien_ff(ien_ff),
        .sel(sel),
        .ar_ld(ar_ld), .ar_clr(ar_clr), .ar_inr(ar_inr),
        .pc_ld(pc_ld), .pc_clr(pc_clr), .pc_inr(pc_inr),
        .dr_ld(dr_ld), .dr_clr(dr_clr), .dr_inr(dr_inr),
        .ac_ld(ac_ld), .ac_clr(ac_clr), .ac_inr(ac_inr),
        .ir_ld(ir_ld), .ir_clr(ir_clr),
        .tr_ld(tr_ld), .tr_clr(tr_clr), .tr_inr(tr_inr),
        .ram_cs(ram_cs), .ram_read(ram_read), .ram_write(ram_write),
        .alu_op(alu_op),
        .e_ld(e_ld), .e_clr(e_clr), .e_inv(e_inv)
    );

    // 3) Memory Unit (RAM - 4096 x 16 bit)
    ram memory (
        .clk(clk),
        .cs(ram_cs),
        .read(ram_read),
        .write(ram_write),
        .addr(ar_out[11:0]), // 12-bit address from AR
        .data_in(ac_out),    // Data written from AC (e.g., STA) or PC (BSA)
        .data_out(ram_data_out)
    );

    // 4) Registers Implementation (AR, PC, DR, AC, IR, TR)
    // Program Counter (PC)
    register_12bit pc_reg (
        .clk(clk), .reset(reset),
        .ld(pc_ld), .clr(pc_clr), .inr(pc_inr),
        .d_in(bus_data[11:0]),
        .d_out(pc_out[11:0])
    );
    assign pc_out[15:12] = 4'b0000; // PC is 12 bits

    // Address Register (AR)
    register_12bit ar_reg (
        .clk(clk), .reset(reset),
        .ld(ar_ld), .clr(ar_clr), .inr(ar_inr),
        .d_in(bus_data[11:0]),
        .d_out(ar_out[11:0])
    );
    assign ar_out[15:12] = 4'b0000;

    // Data Register (DR)
    register_16bit dr_reg (
        .clk(clk), .reset(reset),
        .ld(dr_ld), .clr(dr_clr), .inr(dr_inr),
        .d_in(bus_data),
        .d_out(dr_out)
    );

    // Accumulator (AC) & ALU
    // Accumulator (AC) & ALU
    alu arithmetic_logic_unit (
        .ac_in(ac_out),
        .dr_in(dr_out),
        .inpr_in(in_port[7:0]), // ربطنا البورت الزيادة من الـ in_port لو محتاجه
        .alu_op(alu_op),
        .e_in(e_out),
        .ac_out(alu_out),       // الخرج هيتخزن في الـ wire المؤقت بتاعنا
        .e_out(alu_cout)        // الكاري الجديد الخارج من الـ ALU
    );

    register_16bit ac_reg (
        .clk(clk), .reset(reset),
        .ld(ac_ld), .clr(ac_clr), .inr(ac_inr),
        .d_in(alu_out),
        .d_out(ac_out)
    );

    // Instruction Register (IR)
    register_16bit ir_reg (
        .clk(clk), .reset(reset),
        .ld(ir_ld), .clr(ir_clr), .inr(1'b0),
        .d_in(bus_data),
        .d_out(ir_out)
    );

    // Temporary Register (TR)
    register_16bit tr_reg (
        .clk(clk), .reset(reset),
        .ld(tr_ld), .clr(tr_clr), .inr(tr_inr),
        .d_in(bus_data),
        .d_out(tr_out)
    );

    // Carry Flip-Flop (E)
    // إدارة الـ E Flip-Flop حسب إشارات الـ Control
    reg e_ff;
    always @(posedge clk or posedge reset) begin
        if (reset)
            e_ff <= 1'b0;
        else if (e_clr)
            e_ff <= 1'b0;
        else if (e_ld)
            e_ff <= alu_cout;
        else if (e_inv)
            e_ff <= ~e_ff;
    end
    assign e_out = e_ff;

    // Dummy assignments for I/O flags for now (can be integrated with INPR/OUTR later)
    assign fgi = 1'b1; 
    assign fgo = 1'b1;

endmodule

// Helper Modules for Registers and RAM (لضمان اكتمال السيموليشن والتصميم)
module register_12bit (
    input clk, reset, ld, clr, inr,
    input [11:0] d_in,
    output reg [11:0] d_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) d_out <= 12'b0;
        else if (clr) d_out <= 12'b0;
        else if (ld) d_out <= d_in;
        else if (inr) d_out <= d_out + 1;
    end
endmodule

module register_16bit (
    input clk, reset, ld, clr, inr,
    input [15:0] d_in,
    output reg [15:0] d_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) d_out <= 16'b0;
        else if (clr) d_out <= 16'b0;
        else if (ld) d_out <= d_in;
        else if (inr) d_out <= d_out + 1;
    end
endmodule

module ram (
    input clk, cs, read, write,
    input [11:0] addr,
    input [15:0] data_in,
    output reg [15:0] data_out
);
    reg [15:0] mem [0:4095];
    always @(posedge clk) begin
        if (cs) begin
            if (write) mem[addr] <= data_in;
            if (read) data_out <= mem[addr];
        end
    end
endmodule
