module registers 
(
    input clk, rstn,
    
    // Control signals for **registers** (Load, Clear, Increment)
    // ar | pc | dr | ac | ir | tr | inpr | outr
    input ar_ld, ar_clr, ar_inr,
    input pc_ld, pc_clr, pc_inr,
    input dr_ld, dr_clr, dr_inr,
    input ac_ld, ac_clr, ac_inr,
    input ir_ld, ir_clr,
    input tr_ld, tr_clr, tr_inr,
    input inpr_ld,
    input outr_ld,
    
    // Data inputs
    input [15:0] databus_in, // Input coming from the Common Bus or Memory لكي نضعها في الريجيسترات اتناء التحميل
    input [7:0]  io_in,      // External input for INPR from I/O devices like keyboard or switches
    
    // Outputs to the Common Bus
    // بنفس الترتيب للريحيسترات لتسهيل عملية الربط
    output reg [15:0] ar,
    output reg [11:0] pc,     // PC is typically 12 bits in Mano's basic computer
    output reg [15:0] dr,
    output reg [15:0] ac,
    output reg [15:0] ir,
    output reg [15:0] tr,
    output reg [7:0]  inpr, 
    output reg [7:0]  outr,
    
    // Flip-Flops 
    input e_ld, e_inv, e_clr, // E flip-flop for carry bit in ALU operations
     // inv ---> invert the E flip-flop state
    output reg e,
    
    input ien_set, ien_clr,
    output reg ien,
    
    output reg r_reg // R flip-flop for interrupt cycle
);

    // 1. Address Register (AR - 12 bits)
    always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) 
        ar <= 12'd0;
        else if (ar_clr) ar <= 12'd0;
        else if (ar_inr) ar <= ar + 1;
        else if (ar_ld)  ar <= databus_in[11:0]; // لانه 12 بت فقط هياخد اول 12 بت من الداتاباس
    end

    // 2. Program Counter (PC - 12 bits)
    always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) pc <= 12'd0;
        else if (pc_clr) pc <= 12'd0;
        else if (pc_inr) pc <= pc + 1;
        else if (pc_ld)  pc <= databus_in[11:0];
    end

    // 3. Data Register (DR - 16 bits)
    always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) dr <= 16'd0;
        else if (dr_clr) dr <= 16'd0;
        else if (dr_inr) dr <= dr + 1;
        else if (dr_ld)  dr <= databus_in; // هياخد ال 16 بيت كاملة من الداتاباس
    end

    // 4. Accumulator (AC - 16 bits)
    always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) ac <= 16'd0;
        else if (ac_clr) ac <= 16'd0;
        else if (ac_inr) ac <= ac + 1;
        else if (ac_ld)  ac <= databus_in;
        // ALU الخاصة بـ AC سيتم ربطها لاحقاً هنا أو تمرير نتيجتها عبر الـ databus_in
    end

    // 5. Instruction Register (IR - 16 bits)
    always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) ir <= 16'd0;
        else if (ir_clr) ir <= 16'd0;
        else if (ir_ld)  ir <= databus_in;
        //لابوجد فيه بلس واحد لانه يحمل التعليمات من الذاكره مباشره فقط 
    end

    // 6. Temporary Register (TR - 16 bits)
    always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) tr <= 16'd0;
        else if (tr_clr) tr <= 16'd0;
        else if (tr_inr) tr <= tr + 1;
        else if (tr_ld)  tr <= databus_in;
    end

    // 7. Input Register (INPR - 8 bits)
    always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) inpr <= 8'd0;
        else if (inpr_ld) inpr <= io_in; //يتم تحميل البيانات من جهاز الإدخال الخارجي مثل لوحة المفاتيح 
    end

    // 8. Output Register (OUTR - 8 bits)
    always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) outr <= 8'd0;
        else if (outr_ld) outr <= databus_in[7:0]; // اول 8 بيتات فقط هما الي هيتم تحميلهم من الباص
    end

    // 9. E Flip-Flop (Carry bit) in the ALU in addition and subtraction operations
    always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) e <= 1'b0;
        else if (e_clr) e <= 1'b0; 
        else if (e_inv) e <= ~e; // يتم عكس حالته عند الحاجة من وحدة التحكم
        else if (e_ld)  e <= databus_in[0]; // أو يتم تمرير قيمة الـ Carry من الـ ALU مباشرة
    end

    // 10. IEN (Interrupt Enable Flip-Flop)
    always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) ien <= 1'b0;
        else if (ien_set) ien <= 1'b1; // interrupt enable ----> يتم تفعيله من وحدة التحكم عند الحاجة
        else if (ien_clr) ien <= 1'b0; // interrupt disable ----> يتم تعطيله من وحدة التحكم عند الحاجة
    end

    // 11. R (Interrupt Flip-Flop)
    always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) r_reg <= 1'b0;
        // سيتم التحكم في حالته بناءً على حالة الـ Interrupt والـ IEN في الـ Control Unit
    end
endmodule
