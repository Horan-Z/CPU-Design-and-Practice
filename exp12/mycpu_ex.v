module mycpu_ex(
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        flush_all_i,

    // 输入
    input  wire [31:0] pc_i,
    input  wire        gr_we_i,
    input  wire        csr_we_i,
    input  wire [13:0] csr_wnum_i,
    input  wire [31:0] csr_result_i,
    input  wire [31:0] csr_mask_i,
    input  wire        res_from_mem_i,
    input  wire [ 4:0] dest_i,
    input  wire [18:0] ex_op_i,
    input  wire [31:0] ex_src1_i,
    input  wire [31:0] ex_src2_i,
    input  wire        mem_en_i,
    input  wire        mem_we_i,
    input  wire [ 2:0] mem_size_i,
    input  wire        mem_sign_ext_i,
    input  wire [31:0] rkd_value_i,
    input  wire        is_exc_i,
    input  wire        exc_ecode_i,
    input  wire        is_ertn_i,

    // 给下一级的数据
    output wire [31:0] pc_o,
    output wire        gr_we_o,
    output wire        csr_we_o,
    output wire [13:0] csr_wnum_o,
    output wire [31:0] csr_result_o,
    output wire [31:0] csr_mask_o,
    output wire        res_from_mem_o,
    output wire [ 4:0] dest_o,
    output wire [31:0] ex_result_o,
    output wire [ 2:0] mem_size_o,
    output wire        mem_sign_ext_o,
    output wire        is_exc_o,
    output wire        exc_ecode_o,
    output wire        is_ertn_o,

    // 流水线前递用
    // 标记ex阶段无法获得待写入的寄存器值
    input  wire        ex_not_ready_i,
    output wire        ex_not_ready_o,

    // 控制信号
    input  wire        valid_i,
    input  wire        mem_allowin_i,
    output wire        ex_allowin_o,
    output wire        ex_to_mem_valid_o,

    // data_ram读写信号
    output wire        data_sram_en_o,
    output wire [ 3:0] data_sram_we_o,
    output wire [31:0] data_sram_addr_o,
    output wire [31:0] data_sram_wdata_o
);

wire ex_ready_go = (reg_div_op != 4'd0) ? (div_done | div_complete) : 1'b1;

wire [31:0] alu_result;
wire [31:0] mul_result;
wire [31:0] div_result;
wire        div_start;
wire        div_done;

reg [31:0] reg_pc;
reg        reg_valid;
reg        reg_gr_we;
reg        reg_csr_we;
reg [13:0] reg_csr_wnum;
reg [31:0] reg_csr_result;
reg [31:0] reg_csr_mask;
reg        reg_res_from_mem;
reg [ 4:0] reg_dest;
reg [11:0] reg_alu_op;
reg [ 2:0] reg_mul_op;
reg [ 3:0] reg_div_op;
reg [31:0] reg_cal_src1;
reg [31:0] reg_cal_src2;
reg [31:0] reg_mul_src1;
reg [31:0] reg_mul_src2;
reg        reg_mem_en;
reg        reg_mem_we;
reg [ 2:0] reg_mem_size;
reg        reg_mem_sign_ext;
reg [31:0] reg_rkd_value;
reg        reg_ex_not_ready;
reg        reg_is_exc;
reg [ 5:0] reg_exc_ecode;
reg        reg_is_ertn;

always @(posedge clk_i) begin
    if (reset_i | flush_all_i) begin
        reg_valid <= 1'b0;
    end else if(ex_allowin_o) begin
        reg_valid <= valid_i;
    end
end

always @(posedge clk_i) begin
    if(ex_allowin_o && valid_i) begin
        reg_pc           <= pc_i;
        reg_gr_we        <= gr_we_i;
        reg_csr_we       <= csr_we_i;
        reg_csr_wnum     <= csr_wnum_i;
        reg_csr_result   <= csr_result_i;
        reg_csr_mask     <= csr_mask_i;
        reg_res_from_mem <= res_from_mem_i;
        reg_dest         <= dest_i;
        reg_alu_op       <= ex_op_i[11:0];
        reg_mul_op       <= ex_op_i[14:12];
        reg_div_op       <= ex_op_i[18:15];
        reg_cal_src1     <= ex_src1_i;
        reg_cal_src2     <= ex_src2_i;
        reg_mul_src1     <= ex_src1_i;
        reg_mul_src2     <= ex_src2_i;
        reg_mem_en       <= mem_en_i;
        reg_mem_we       <= mem_we_i;
        reg_mem_size     <= mem_size_i;
        reg_mem_sign_ext <= mem_sign_ext_i;
        reg_rkd_value    <= rkd_value_i;
        reg_ex_not_ready <= ex_not_ready_i;
        reg_is_exc       <= is_exc_i;
        reg_exc_ecode    <= exc_ecode_i;
        reg_is_ertn      <= is_ertn_i;
    end
end

reg div_complete;
always @(posedge clk_i) begin
    if (reset_i) begin              // 高电平同步复位
        div_complete <= 1'b0;
    end else if (reg_valid && ex_ready_go && mem_allowin_i) begin
        div_complete <= 1'b0;       // 握手成功，指令离开 EX 级，清零记忆
    end else if (div_done) begin
        div_complete <= 1'b1;       // 除法算完但走不掉，记忆完成状态
    end
end

assign div_start = reg_valid && (reg_div_op != 4'd0) && !div_complete;

// 中转信号
assign pc_o           = reg_pc;
assign gr_we_o        = reg_gr_we;
// 因为csr_we_o同时也做ID阶段的阻塞控制信号，所以这里不判断是否valid的话就会死锁
assign csr_we_o       = reg_csr_we && reg_valid;
assign csr_wnum_o     = reg_csr_wnum;
assign csr_result_o   = reg_csr_result;
assign csr_mask_o     = reg_csr_mask;
assign res_from_mem_o = reg_res_from_mem;

// 如果不是valid，就释放dest，防止死锁
assign dest_o         = reg_valid ? reg_dest : 5'd0;
// 不需要判断reg_gr_we，已在ID阶段处理，如果不需要写入此处dest_0已经被设定为5'd0了
// assign dest_o         = reg_valid && reg_gr_we ? reg_dest : 5'd0;

assign mem_size_o = reg_mem_size;
assign mem_sign_ext_o = reg_mem_sign_ext;

// 当前课后实践阶段ex级流水不会触发异常
assign ex_trigger_exc = 1'b0;
assign ex_exc_ecode   = 6'd0;
assign is_exc_o       = reg_is_exc | ex_trigger_exc;
assign exc_ecode_o    = reg_is_exc ? reg_exc_ecode : ex_exc_ecode;
assign is_ertn_o      = reg_is_ertn;

assign ex_not_ready_o = reg_ex_not_ready;

assign ex_allowin_o = !reg_valid || (ex_ready_go && mem_allowin_i);
assign ex_to_mem_valid_o = reg_valid && ex_ready_go;

assign data_sram_en_o    = reg_mem_en & ex_to_mem_valid_o & mem_allowin_i;

wire [3:0] byte_we_mask;
wire [3:0] half_we_mask;
assign byte_we_mask = ({4{alu_result[1:0] == 2'b00}} & 4'b0001) |
                      ({4{alu_result[1:0] == 2'b01}} & 4'b0010) |
                      ({4{alu_result[1:0] == 2'b10}} & 4'b0100) |
                      ({4{alu_result[1:0] == 2'b11}} & 4'b1000) ;
assign half_we_mask = ({4{alu_result[1]   == 1'b0}}  & 4'b0011) |
                      ({4{alu_result[1]   == 1'b1}}  & 4'b1100) ;
assign data_sram_we_o = {4{reg_mem_we & ex_to_mem_valid_o & mem_allowin_i}} & (
                            ({4{reg_mem_size[0]}} & byte_we_mask) |
                            ({4{reg_mem_size[1]}} & half_we_mask) |
                            ({4{reg_mem_size[2]}} & 4'b1111)
                        );

assign data_sram_addr_o  = {alu_result[31:2], 2'b00};
assign data_sram_wdata_o = ({32{reg_mem_size[0]}} & {4{reg_rkd_value[ 7:0]}}) |
                           ({32{reg_mem_size[1]}} & {2{reg_rkd_value[15:0]}}) |
                           ({32{reg_mem_size[2]}} & reg_rkd_value);

assign ex_result_o       = {32{reg_alu_op != 12'd0}} & alu_result |
                           {32{reg_mul_op !=  3'd0}} & mul_result |
                           {32{reg_div_op !=  4'd0}} & div_result ;

alu u_alu(
    .alu_op     (reg_alu_op  ),
    .alu_src1   (reg_cal_src1),
    .alu_src2   (reg_cal_src2),
    .alu_result (alu_result  )
);

mul u_mul(
    .mul_op     (reg_mul_op  ),
    .mul_src1   (reg_mul_src1),
    .mul_src2   (reg_mul_src2),
    .mul_result (mul_result  )
);

div u_div(
    .clk        (clk_i       ),
    .reset      (reset_i     ),
    .div_start  (div_start   ),
    .div_done   (div_done    ),
    .div_op     (reg_div_op  ),  
    .div_src1   (reg_cal_src1),
    .div_src2   (reg_cal_src2),
    .div_result (div_result  )
);

endmodule