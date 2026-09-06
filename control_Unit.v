module control_unit 
(
    input clk,
    input reset,
    input [15:0] ir_in,  // Instruction Register input
    input [15:0] dr_in,  // Data Register input for ISZ instruction
    input [15:0] ac_in,  // Accumulator input for certain instructions
    input e_in,          // Carry bit input for certain instructions
    input fgi,           // Input flag from INPR indicating data is ready
    input fgo,           // Output flag from OUTR indicating ready to send data
    input ien_in,        // Interrupt Enable Flip-Flop input
    
    // Outputs --> Control signals to registers, ALU, RAM, and other system components
    // هيبعت اشارات للتحكم في كل الريجيسترات والرام والاليو
    output reg [3:0] sc, // Sequence Counter for timing control T0 --> T15
    output reg r_ff,
    output reg ien_ff,
    output reg [2:0] sel,
    output reg ar_ld, ar_clr, ar_inr,
    output reg pc_ld, pc_clr, pc_inr,
    output reg dr_ld, dr_clr, dr_inr,
    output reg ac_ld, ac_clr, ac_inr,
    output reg ir_ld, ir_clr,
    output reg tr_ld, tr_clr, tr_inr,
    output reg ram_cs, ram_read, ram_write,
    output reg [2:0] alu_op,
    output reg e_ld, e_clr, e_inv
);

    // Internal signals for decoding
    // IR[14:12] for opcode, IR[15] for indirect bit
    // دي طبعا الداتا الي من خلالها هنعرف نوع الامر الي هيتم تنفيذه
    wire [2:0] opcode = ir_in[14:12]; // ال 3 بيت دول من 0 الى 6 الامر يكون ميموري ريفرينس 
    wire indirect_bit = ir_in[15];    // لو ال 3 بيت الي فوق ب 111 خلاص ده الي هيحدد الامر 
                                      // [0] ---> register reference instruction
                                      // [1] ---> I/O instruction
    
    // Decoders D0 to D7 based on IR[14:12]
    reg [7:0] d; // بيت واحد فقط منها هو الي بواحد 
    always @(*) begin
        d = 8'b0;
        case (opcode)
            3'b000: d = 8'b00000001; // D0
            3'b001: d = 8'b00000010; // D1
            3'b010: d = 8'b00000100; // D2
            3'b011: d = 8'b00001000; // D3
            3'b100: d = 8'b00010000; // D4
            3'b101: d = 8'b00100000; // D5
            3'b110: d = 8'b01000000; // D6
            3'b111: d = 8'b10000000; // D7
        endcase
    end

    // Helper signal for sign bit of accumulator
    wire ac_in_sign = ac_in[15];

    always @(posedge clk or posedge reset) // Active-High Reset for Control Unit asynchronous reset
    begin
        if (reset) 
        begin
            sc     <= 4'b0000;
            r_ff   <= 1'b0;
            ien_ff <= 1'b0;
            sel    <= 3'b000;
            ar_ld  <= 1'b0; ar_clr <= 1'b0; ar_inr <= 1'b0;
            pc_ld  <= 1'b0; pc_clr <= 1'b0; pc_inr <= 1'b0;
            dr_ld  <= 1'b0; dr_clr <= 1'b0; dr_inr <= 1'b0;
            ac_ld  <= 1'b0; ac_clr <= 1'b0; ac_inr <= 1'b0;
            ir_ld  <= 1'b0; ir_clr <= 1'b0;
            tr_ld  <= 1'b0; tr_clr <= 1'b0; tr_inr <= 1'b0;
            ram_cs <= 1'b0; ram_read <= 1'b0; ram_write <= 1'b0;
            alu_op <= 3'b000;
            e_ld   <= 1'b0; e_clr <= 1'b0; e_inv <= 1'b0;
        end 
        else 
        begin
            // Default pulse control signals to 0 each clock cycle unless asserted
            ar_ld  <= 1'b0; ar_inr <= 1'b0; ar_clr <= 1'b0;
            pc_ld  <= 1'b0; pc_inr <= 1'b0; pc_clr <= 1'b0;
            dr_ld  <= 1'b0; dr_inr <= 1'b0; dr_clr <= 1'b0;
            ac_ld  <= 1'b0; ac_clr <= 1'b0; ac_inr <= 1'b0;
            ir_ld  <= 1'b0; ir_clr <= 1'b0;
            tr_ld  <= 1'b0; tr_inr <= 1'b0; tr_clr <= 1'b0;
            ram_cs <= 1'b0; ram_read <= 1'b0; ram_write <= 1'b0;
            e_ld   <= 1'b0; e_clr  <= 1'b0; e_inv   <= 1'b0;

            // Sequence Counter management
            sc <= sc + 1;

            if (r_ff == 0) 
            begin
                case (sc)
                    4'b0000: begin // R'T0: AR <- PC
                        sel    = 3'b010; // PC to Bus
                        ar_ld  = 1'b1;
                        ram_cs = 1'b1; ram_read = 1'b0; ram_write = 1'b0;
                    end
                    
                    4'b0001: begin // R'T1: IR <- M[AR], PC <- PC + 1
                        sel    = 3'b111; // Memory to Bus
                        ir_ld  = 1'b1;
                        pc_inr = 1'b1;
                        ram_cs = 1'b1; ram_read = 1'b1;
                    end
                    
                    4'b0010: begin // R'T2: AR <- IR(0-11), I <- IR(15)
                        sel    = 3'b101; // IR to Bus
                        ar_ld  = 1'b1;
                        // هو بيفترض الاول ان الامر ميموري ريفرينس وبعد كده هيشوف لو كان ديركت او اندايركت
                    end
                    
                    // 2) INDIRECT CYCLE (D_7' I T_3)
                    4'b0011: begin 
                        if ((d[7] == 0) && (indirect_bit == 1)) 
                        begin
                            // D7' I T3: AR <- M[AR] (Indirect Address Fetch)
                            sel    = 3'b111;
                            ar_ld  = 1'b1;
                            ram_cs = 1'b1; ram_read = 1'b1;
                        end
                        else if ((d[7] == 0) && (indirect_bit == 0)) 
                        begin
                            // D7' I' T3: Direct Address (No operation needed on AR, proceed to T4)
                        end
                        else if (d[7] && (indirect_bit == 0))  
                        // ده امر ريجستر ريفرينس و مش محتاج اي تايمينج تاني غير الي بعده عشان ينفذ الامر
                        begin
                            // Register-Reference Instructions (D_7 I' T_3)
                            case (ir_in[11:0])
                                12'h800: ac_clr = 1'b1;                        // CLA
                                12'h400: e_clr  = 1'b1;                        // CLE
                                12'h200: begin alu_op = 3'b010; ac_ld = 1; end // AC <- ~AC (CMA) from ALU
                                12'h100: e_inv  = 1'b1;                        // e <- ~e (CME)
                                12'h080: begin alu_op = 3'b100; ac_ld = 1; e_ld = 1; end // CIR
                                12'h040: begin alu_op = 3'b101; ac_ld = 1; e_ld = 1; end // CIL
                                12'h020: begin alu_op = 3'b110; ac_ld = 1; e_ld = 1; end // INC
                                12'h010: if (ac_in_sign == 0) pc_inr = 1;      // SPA
                                12'h008: if (ac_in_sign == 1) pc_inr = 1;      // SNA
                                12'h004: if (e_in == 0) pc_inr = 1;            // SZA
                                12'h002: if (e_in == 1) pc_inr = 1;            // SZE
                                12'h001: r_ff   = 1'b1;                        // HLT توقف كل العمليات ويدخل في حالة الانتظار
                            endcase
                            sc <= 4'b0000; // Reset SC for Reg-Ref to repeat timing cycle to t0
                        end
                        else if (d[7] && (indirect_bit == 1)) 
                        // ده امر ادخال او اخراج محتاج تايمينج 3 عشان ينفذ الامر و بعد كده يصفر العداد
                        begin
                            // I/O Instructions (D_7 I T_3) based on IR[11:0]
                            case (ir_in[11:0])
                                12'h800: begin /* INP logic */ end
                                12'h400: begin /* OUT logic */ end
                                12'h200: if (fgi) pc_inr = 1;  // SKI
                                12'h100: if (fgo) pc_inr = 1; // SKO
                                12'h080: ien_ff = 1;        // ION --> interrupt enable
                                12'h040: ien_ff = 0;        // IOF --> interrupt disable
                            endcase
                            sc <= 4'b0000; // Reset SC for I/O to repeat timing cycle to t0
                        end
                    end
     // التايمنج الي جاي كله خلاص لتنفيذ اوامر الميموري في الي هيحتاج اربعه فقط وفي الي يختاج 4و 5  وفي الي محتاج 4و5و6
                    // 3) MEMORY-REFERENCE INSTRUCTIONS (D0 to D6) - Execution at T4
                    4'b0100: begin 
     // اوامر الاند و الجمع و التحميل لازم الاول اعطي البيانت في تايمينج و بعد كده التايمنج الي بعده التنفيذ ب alu
                        if (d[0]) begin      // AND: D0 T4: DR <- M[AR]
                            sel    = 3'b111;
                            dr_ld  = 1'b1;
                            ram_cs = 1'b1; ram_read = 1'b1;
                        end
                        else if (d[1]) begin // ADD: D1 T4: DR <- M[AR]
                            sel    = 3'b111;
                            dr_ld  = 1'b1;
                            ram_cs = 1'b1; ram_read = 1'b1;
                        end
                        else if (d[2]) begin // LDA: D2 T4: DR <- M[AR]
                            sel    = 3'b111;
                            dr_ld  = 1'b1;
                            ram_cs = 1'b1; ram_read = 1'b1;
                        end
     // الامرين التخزين و القفز لعنوات معين خلاص بيحتاجو  تايمينج 4 بس وينتتهوا هنا و العداد يصفر
                        else if (d[3]) 
                        begin // STA: D3 T4: M[AR] <- AC, SC <- 0
                            //  امر تخزين البيانات في الذاكرة من الذاكرة المؤقتة الاكيولاتور الي الذاكرة الرئيسية
                            sel    = 3'b100; // AC to Bus
                            ram_cs = 1'b1; ram_write = 1'b1;
                            sc     <= 4'b0000; // Reset SC
                        end
                        else if (d[4]) 
                        begin // BUN: D4 T4: PC <- AR, SC <- 0
                        // امر القفز الي عنوان معين في الذاكرة الرئيسية الرام
                            sel    = 3'b001; // AR to Bus
                            pc_ld  = 1'b1;
                            sc     <= 4'b0000; // Reset SC
                        end
                        else if (d[5]) begin // BSA: D5 T4: M[AR] <- PC, AR <- AR + 1
// امر القفز الي عنوان معين في الذاكرة الرئيسية الرام و تخزين العنوان الحالي في الذاكرة المؤقتة الاكيولاتور نفس منطق عمل الداله 
                            sel    = 3'b010; // PC to Bus
                            ram_cs = 1'b1; ram_write = 1'b1;
                            sc     <= 4'b0101; // Go to T5
                        end
                        else if (d[6]) begin // ISZ: D6 T4: DR <- M[AR]
                            sel    = 3'b111;
                            dr_ld  = 1'b1;
                            ram_cs = 1'b1; ram_read = 1'b1;
                        end
                    end

                    // Execution at T5
                    4'b0101: begin 
                        if (d[0]) begin      // AND: D0 T5: AC <- AC ^ DR, SC <- 0
                            alu_op = 3'b000; 
                            ac_ld  = 1'b1;
                            sc     <= 4'b0000;
                        end
                        else if (d[1]) begin // ADD: D1 T5: AC <- AC + DR, E <- Cout, SC <- 0
                            alu_op = 3'b001; 
                            ac_ld  = 1'b1; 
                            e_ld   = 1'b1;
                            sc     <= 4'b0000;
                        end
                        else if (d[2]) begin // LDA: D2 T5: AC <- DR, SC <- 0
                            sel    = 3'b011; // DR to Bus
                            ac_ld  = 1'b1;
                            sc     <= 4'b0000;
                        end
            // ممكن نكتب 3 و 4 وممكن لا براحتنا انا كتبتهم علشان ااكد انهم انتهو في التايمنج السابق 
                        else if (d[3]) begin // STA: D3 T5: Already handled in T4, SC <- 0
                            sc     <= 4'b0000;
                        end
                        else if (d[4]) begin // BUN: D4 T5: Already handled in T4, SC <- 0
                            sc     <= 4'b0000;
                        end
                        //--------
                        else if (d[5]) 
                        begin // BSA: D5 T5: PC <- AR + 1, SC <- 0
                            pc_inr = 1'b1;
                            sc     <= 4'b0000;
                        end
                        else if (d[6]) // لسه امر الزيادة في العداد محتاج تايمينج 6 عشان ينفذ العملية و بعد كده يصفر العداد
                        begin // ISZ: D6 T5: DR <- DR + 1
                            alu_op = 3'b110; // INC operation
                            dr_ld  = 1'b1;
                            sc     <= 4'b0110; // Go to T6 for write-back
                        end
                    end

                    // T6 for ISZ
                    4'b0110: begin 
                        if (d[6]) begin // D6 T6: M[AR] <- DR, if (DR == 0) PC <- PC + 1, SC <- 0
                            sel    = 3'b011; // DR to Bus
                            ram_cs = 1'b1; ram_write = 1'b1;
                            if (dr_in == 16'b0) begin
                                pc_inr = 1'b1;
                            end
                            sc     <= 4'b0000;
                        end
                    end

                endcase
            end
        end
    end

endmodule
