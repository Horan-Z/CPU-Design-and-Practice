module mycpu_id(
    input  wire        clk_i,
    input  wire        reset_i,

    // 输入
    input  wire [31:0] pc_i,
    input  wire [31:0] inst_i,

    // 给下一级的数据
    output wire [31:0] pc_o,
    output wire        gr_we_o,
    output wire        res_from_mem_o,
    output wire [ 4:0] dest_o,
    output wire [18:0] ex_op_o,
    output wire [31:0] ex_src1_o,
    output wire [31:0] ex_src2_o,
    output wire        mem_en_o,
    output wire [ 3:0] mem_we_o,
    output wire [ 2:0] mem_size_o,
    output wire        mem_sign_ext_o,
    output wire [31:0] rkd_value_o,

    // 分支跳转
    output wire        br_taken_o,
    output wire [31:0] br_target_o,
    output wire        br_taken_cancel_o,

    // 读寄存器
    output wire [ 4:0] rf_raddr1_o,
    input  wire [31:0] rf_rdata1_i,
    output wire [ 4:0] rf_raddr2_o,
    input  wire [31:0] rf_rdata2_i,

    // 流水线前递用
    input  wire [ 4:0] ex_dest_i,
    input  wire [31:0] ex_write_reg_i,
    input  wire [ 4:0] mem_dest_i,
    input  wire [31:0] mem_write_reg_i,
    input  wire [ 4:0] wb_dest_i,
    input  wire [31:0] wb_write_reg_i,
    // 标记ex阶段无法获得待写入的寄存器值
    input  wire        ex_not_ready_i,
    output wire        ex_not_ready_o,

    // 控制信号
    input  wire        valid_i,
    input  wire        ex_allowin_i,
    output wire        id_allowin_o,
    output wire        id_to_ex_valid_o
);

wire       id_ready_go;

wire       read_en_1; // 读rj的此处为true
wire       read_en_2; // 读rk或者rd的此处为true

assign     read_en_1   = inst_add_w  | inst_sub_w  | inst_slt    | inst_sltu   |
                         inst_nor    | inst_and    | inst_or     | inst_xor    |
                         inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w |
                         inst_div_w  | inst_div_wu | inst_mod_w  | inst_mod_wu |
                         inst_blt    | inst_bltu   | inst_bge    | inst_bgeu   |
                         inst_ld_b   | inst_ld_bu  | inst_ld_h   | inst_ld_hu  |
                         inst_mul_w  | inst_mulh_w | inst_mulh_wu|
                         inst_ld_w   | inst_st_w   | inst_jirl   |
                         inst_andi   | inst_ori    | inst_xori   |
                         inst_sll_w  | inst_srl_w  | inst_sra_w  |
                         inst_slti   | inst_sltui  |
                         inst_bne    | inst_beq    ;

assign     read_en_2   = inst_add_w  | inst_sub_w  | inst_slt    | inst_sltu   |
                         inst_nor    | inst_and    | inst_or     | inst_xor    |
                         inst_div_w  | inst_div_wu | inst_mod_w  | inst_mod_wu |
                         inst_blt    | inst_bltu   | inst_bge    | inst_bgeu   |
                         inst_mul_w  | inst_mulh_w | inst_mulh_wu|
                         inst_sll_w  | inst_srl_w  | inst_sra_w  |
                         inst_st_w   |
                         inst_bne    | inst_beq    ;

assign     id_ready_go = ~( 
    (read_en_1 && (rf_raddr1 != 5'd0) && ((rf_raddr1 == ex_dest_i) && ex_not_ready_i)) |
    (read_en_2 && (rf_raddr2 != 5'd0) && ((rf_raddr2 == ex_dest_i) && ex_not_ready_i))
);

reg [31:0] reg_pc;
reg [31:0] reg_inst;
reg        reg_valid;

always @(posedge clk_i) begin
    if (reset_i) begin
        reg_valid <= 1'b0;
    end else if(br_taken_cancel_o) begin
        // 这里的意思是清空下一次到来的数据，而不是清空现在的数据
        // 所以br_taken_cancel_o只有在当前周期数据成功发送到下一级流水的时候才可以为true
        reg_valid <= 1'b0;
    end else if(id_allowin_o) begin
        reg_valid <= valid_i;
    end
end

always @(posedge clk_i) begin
    if(id_allowin_o && valid_i) begin
        reg_pc   <= pc_i;
        reg_inst <= inst_i;
    end
end

wire        br_taken;
wire [31:0] br_target;

// br_taken_cancel_o必须在当前id数据传入下一层ex的时候才能为true
// 如果因为任何原因，当前id处于阻塞中，那么br_taken_cancel_o不能为true
// 否则，上方时序逻辑中的【else if(br_taken_cancel_o)】会触发，直接清空id层级
assign br_taken_cancel_o = br_taken & id_to_ex_valid_o & ex_allowin_i;

wire [11:0] alu_op;
wire [ 2:0] mul_op;
wire [ 3:0] div_op;
wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        dst_is_r1;
wire        src_reg_is_rd;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_div_wu;
wire        inst_mod_w;
wire        inst_mod_wu;
wire        inst_slt;
wire        inst_slti;
wire        inst_sltu;
wire        inst_sltui;
wire        inst_nor;
wire        inst_and;
wire        inst_andi;
wire        inst_or;
wire        inst_ori;
wire        inst_xor;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_slli_w;
wire        inst_srl_w;
wire        inst_srli_w;
wire        inst_sra_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_ld_b;
wire        inst_ld_bu;
wire        inst_ld_h;
wire        inst_ld_hu;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_blt;
wire        inst_bltu;
wire        inst_bge;
wire        inst_bgeu;
wire        inst_lu12i_w;
wire        inst_pcaddu12i;

wire        need_ui5;
wire        need_si12;
wire        need_ze12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata1;
wire [31:0] rf_rdata2;

assign op_31_26  = reg_inst[31:26];
assign op_25_22  = reg_inst[25:22];
assign op_21_20  = reg_inst[21:20];
assign op_19_15  = reg_inst[19:15];

assign rd   = reg_inst[ 4: 0];
assign rj   = reg_inst[ 9: 5];
assign rk   = reg_inst[14:10];

assign i12  = reg_inst[21:10];
assign i20  = reg_inst[24: 5];
assign i16  = reg_inst[25:10];
assign i26  = {reg_inst[ 9: 0], reg_inst[25:10]};

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_blt    = op_31_26_d[6'h18];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bgeu   = op_31_26_d[6'h1b];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~reg_inst[25];
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~reg_inst[25];

assign load_op    = inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu;

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_st_w | inst_jirl | inst_bl | inst_pcaddu12i;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt  | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and  | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or   | inst_ori;
assign alu_op[ 7] = inst_xor  | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;

assign mul_op[ 0] = inst_mul_w;
assign mul_op[ 1] = inst_mulh_w;
assign mul_op[ 2] = inst_mulh_wu;

assign div_op[ 0] = inst_div_w;
assign div_op[ 1] = inst_div_wu;
assign div_op[ 2] = inst_mod_w;
assign div_op[ 3] = inst_mod_wu;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_st_w | inst_slti | inst_sltui;
assign need_ze12  =  inst_andi | inst_ori | inst_xori;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bltu | inst_bge | inst_bgeu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ze12 ? {{20{1'b0}}, i12[11:0]}    :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bltu | inst_bge | inst_bgeu | inst_st_w;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_ld_b   | 
                       inst_ld_bu  |
                       inst_ld_h   |
                       inst_ld_hu  |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_pcaddu12i;

assign res_from_mem_o = inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu;
assign dst_is_r1      = inst_bl;
assign gr_we_o        = ~(inst_st_w | inst_beq | inst_bne | inst_b | inst_blt | inst_bltu | inst_bge | inst_bgeu) & reg_valid;
assign mem_we_o       = {4{inst_st_w}} & {4{reg_valid}};
assign mem_size_o = ({3{inst_ld_b}}  & 3'b001) |
                    ({3{inst_ld_bu}} & 3'b001) |
                    ({3{inst_ld_h}}  & 3'b010) |
                    ({3{inst_ld_hu}} & 3'b010) |
                    ({3{inst_ld_w}}  & 3'b100) ;
assign mem_sign_ext_o = inst_ld_b | inst_ld_h;
assign mem_en_o       = (inst_st_w | inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu) & reg_valid;
assign pc_o           = reg_pc;

// 提前处理dest
// 如果不需要写入，将dest设置为0号寄存器
// 因为0号寄存器不可能写入，相当于标记了不需要写入
// 省下了gr_we信号回传
assign dest_o         = gr_we_o ? (dst_is_r1 ? 5'd1 : rd) : 5'd0;

assign ex_not_ready_o = inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd : rk;

assign rj_value  = rf_rdata1;
assign rkd_value = rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);

wire [31:0] lt_result;
wire        rj_ge_rd_u;
assign {rj_ge_rd_u, lt_result} = rj_value + ~rkd_value + 1'b1;
assign rj_lt_rd = (rj_value[31] & ~rkd_value[31]) | ((rj_value[31] ~^ rkd_value[31]) & lt_result[31]);

assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_blt  &&  rj_lt_rd
                   || inst_bge  && !rj_lt_rd
                   || inst_bltu && !rj_ge_rd_u
                   || inst_bgeu &&  rj_ge_rd_u
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && id_to_ex_valid_o;
// br_taken最后的条件从reg_valid改为了id_to_ex_valid_o
// 因为当后方流水还没完成写入，还处于Read after Write竞争中时
// rj_eq_rd是不准确的，如果不判定id_ready_go，就会导致前面流水收到错误的br_taken信息
// 那么为什么不直接【id_to_ex_valid_o && ex_allowin_i】，然后让br_taken_cancel直接等于br_taken呢
// 因为这样br_taken可以在阻塞的时候先于br_taken_cancel变为true，让前面流水提前拿到正确的pc
// 节省一些cpu cycle

assign br_target = (inst_beq | inst_bne | inst_bl | inst_b | inst_blt | inst_bltu | inst_bge | inst_bgeu) ? (reg_pc + br_offs) :
                                                                                              /*inst_jirl*/ (rj_value + jirl_offs);

assign ex_src1_o = src1_is_pc  ? reg_pc[31:0] : rj_value;
assign ex_src2_o = src2_is_imm ? imm : rkd_value;
assign ex_op_o   = {div_op, mul_op, alu_op};

assign rkd_value_o = rkd_value;
assign br_taken_o  = br_taken;
assign br_target_o = br_target;

assign rf_raddr1_o = rf_raddr1; // rj
assign rf_rdata1   = rf_raddr1 != 5'd0 && rf_raddr1 ==  ex_dest_i ?  ex_write_reg_i :
                     rf_raddr1 != 5'd0 && rf_raddr1 == mem_dest_i ? mem_write_reg_i :
                     rf_raddr1 != 5'd0 && rf_raddr1 ==  wb_dest_i ?  wb_write_reg_i :
                                                                        rf_rdata1_i ;

assign rf_raddr2_o = rf_raddr2; // rk 或者 rd
assign rf_rdata2   = rf_raddr2 != 5'd0 && rf_raddr2 ==  ex_dest_i ?  ex_write_reg_i :
                     rf_raddr2 != 5'd0 && rf_raddr2 == mem_dest_i ? mem_write_reg_i :
                     rf_raddr2 != 5'd0 && rf_raddr2 ==  wb_dest_i ?  wb_write_reg_i :
                                                                        rf_rdata2_i ;

assign id_allowin_o = !reg_valid || (id_ready_go && ex_allowin_i);
assign id_to_ex_valid_o = reg_valid && id_ready_go;

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

endmodule