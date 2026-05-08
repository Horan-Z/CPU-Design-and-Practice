module mycpu_wb(
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        flush_all_i,

    // 输入
    input  wire [31:0] pc_i,
    input  wire        valid_i,
    input  wire        gr_we_i,
    input  wire        csr_we_i,
    input  wire [13:0] csr_wnum_i,
    input  wire [31:0] write_result_i,
    input  wire [31:0] write_csr_i,
    input  wire [31:0] csr_mask_i,
    input  wire [ 4:0] dest_i,
    input  wire        is_exc_i,
    input  wire [ 5:0] exc_ecode_i,
    input  wire        is_ertn_i,

    // 写寄存器
    output wire        rf_we_o,
    output wire [ 4:0] rf_waddr_o,
    output wire [31:0] rf_wdata_o,
    output wire [ 4:0] dest_o,
    output wire        csr_we_o,
    output wire [13:0] csr_wnum_o,
    output wire [31:0] csr_mask_o,
    output wire [31:0] csr_wvalue_o,
    output wire        wb_exc_o,
    output wire [ 5:0] wb_ecode_o,
    output wire [31:0] wb_pc_o,
    output wire        ertn_flush_o,
    output wire        flush_all_o,

    // debug信号
    output wire [31:0] debug_wb_pc_o,
    output wire [ 3:0] debug_wb_rf_we_o,
    output wire [ 4:0] debug_wb_rf_wnum_o,
    output wire [31:0] debug_wb_rf_wdata_o,

    // 控制信号
    output wire        wb_allowin_o
);

wire       wb_ready_go = 1'b1;

reg [31:0] reg_pc;
reg        reg_valid;
reg        reg_gr_we;
reg        reg_csr_we;
reg [13:0] reg_csr_wnum;
reg [31:0] reg_write_result;
reg [31:0] reg_write_csr;
reg [31:0] reg_csr_mask;
reg [ 4:0] reg_dest;
reg        reg_is_exc;
reg [ 5:0] reg_exc_ecode;
reg        reg_is_ertn;

always @(posedge clk_i) begin
    if (reset_i | flush_all_i) begin
        reg_valid <= 1'b0;
    end else if(wb_allowin_o) begin
        // 这里也需要判断wb_allowin_o的原因是防止在本级处理完毕之前就关掉了valid信号
        reg_valid <= valid_i;
    end
end

// 不能把这个时序逻辑合并到上面变为【else if(wb_allowin_o && valid_i)】
// 会导致reg_valid卡在true无法更新
always @(posedge clk_i) begin
    if(wb_allowin_o && valid_i) begin
        reg_pc           <= pc_i;
        reg_gr_we        <= gr_we_i;
        reg_csr_we       <= csr_we_i;
        reg_csr_wnum     <= csr_wnum_i;
        reg_write_result <= write_result_i;
        reg_write_csr    <= write_csr_i;
        reg_csr_mask     <= csr_mask_i;
        reg_dest         <= dest_i;
        reg_is_exc       <= is_exc_i;
        reg_exc_ecode    <= exc_ecode_i;
        reg_is_ertn      <= is_ertn_i;
    end
end

assign rf_we_o    = reg_gr_we && reg_valid;
assign rf_waddr_o = reg_dest;
assign rf_wdata_o = reg_write_result;

// 如果不是valid，就释放dest，防止死锁
assign dest_o         = reg_valid ? reg_dest : 5'd0;
// 不需要判断reg_gr_we，已在ID阶段处理，如果不需要写入此处dest_0已经被设定为5'd0了
// assign dest_o         = reg_valid && reg_gr_we ? reg_dest : 5'd0;

// wb级流水不会触发异常
// 因为csr_we_o同时也做ID阶段的阻塞控制信号，所以这里不判断是否valid的话就会死锁
assign csr_we_o     = reg_csr_we && reg_valid;
assign csr_wnum_o   = reg_csr_wnum;
assign csr_mask_o   = reg_csr_mask;
assign csr_wvalue_o = reg_write_csr;
assign wb_exc_o     = reg_is_exc & reg_valid;
assign wb_ecode_o   = reg_exc_ecode;
assign wb_pc_o      = reg_pc;
assign ertn_flush_o = reg_is_ertn & reg_valid;
assign flush_all_o  = (reg_is_exc | reg_is_ertn) & reg_valid;

assign debug_wb_pc_o       = reg_pc;
assign debug_wb_rf_we_o    = {4{rf_we_o}};
assign debug_wb_rf_wnum_o  = rf_waddr_o;
assign debug_wb_rf_wdata_o = rf_wdata_o;

assign wb_allowin_o = !reg_valid || wb_ready_go;

endmodule