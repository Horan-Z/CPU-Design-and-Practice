module mycpu_mem(
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
    input  wire [31:0] ex_result_i,
    input  wire [ 4:0] dest_i,
    input  wire        mem_en_i,
    input  wire [31:0] data_sram_rdata_i,
    input  wire        data_data_ok_i,
    input  wire [ 2:0] mem_size_i,
    input  wire        mem_sign_ext_i,
    input  wire        is_exc_i,
    input  wire [ 5:0] exc_ecode_i,
    input  wire        is_ertn_i,
    input  wire [31:0] wb_vaddr_i,

    // 给下一级的数据
    output wire [31:0] pc_o,
    output wire        gr_we_o,
    output wire        csr_we_o,
    output wire [13:0] csr_wnum_o,
    output wire        mem_waiting_o,
    output wire [31:0] write_result_o,
    output wire [31:0] write_csr_o,
    output wire [31:0] csr_mask_o,
    output wire [ 4:0] dest_o,
    output wire        is_exc_o,
    output wire [ 5:0] exc_ecode_o,
    output wire        is_ertn_o,
    output wire [31:0] wb_vaddr_o,

    // 控制信号
    input  wire        valid_i,
    input  wire        ex_pending_i,
    input  wire        wb_allowin_i,
    output wire        mem_allowin_o,
    output wire        mem_to_wb_valid_o
);

// 只有真正发起了访存的指令才会需要等待
wire        mem_inst      = reg_mem_en & !reg_is_exc;
wire        valid_data_ok = data_data_ok_i & (data_cancel_cnt == 2'd0) & !flush_all_i;
wire        mem_ready_go  = !mem_inst | cached_data_ok | valid_data_ok;
assign      mem_waiting_o = ~mem_ready_go;

reg  [31:0] cached_data;
reg         cached_data_ok;
reg  [ 1:0] data_cancel_cnt;
wire [31:0] real_rdata  = cached_data_ok ? cached_data : data_sram_rdata_i;
wire        mem_pending = reg_valid && reg_mem_en && !reg_is_exc && !cached_data_ok && !(data_data_ok_i && data_cancel_cnt == 2'd0);

wire [31:0] mem_result;
wire [ 3:0] mem_mask;
wire [ 7:0] byte_data;
wire [15:0] half_data;

reg [31:0] reg_pc;
reg        reg_valid;
reg        reg_gr_we;
reg        reg_csr_we;
reg [13:0] reg_csr_wnum;
reg [31:0] reg_csr_result;
reg [31:0] reg_csr_mask;
reg        reg_res_from_mem;
reg [31:0] reg_ex_result;
reg [ 4:0] reg_dest;
reg        reg_mem_en;
reg [ 2:0] reg_mem_size;
reg        reg_mem_sign_ext;
reg        reg_is_exc;
reg [ 5:0] reg_exc_ecode;
reg        reg_is_ertn;
reg [31:0] reg_wb_vaddr;

always @(posedge clk_i) begin
    if (reset_i) begin
        data_cancel_cnt <= 2'd0;
    end else if (flush_all_i) begin
        // 发生异常时：新的作废数量 = (原有作废数 + EX在途 + MEM在途) - (如果这拍刚好有数据返回，则直接抵消1个)
        data_cancel_cnt <= data_cancel_cnt + ex_pending_i + mem_pending - (data_data_ok_i & (|data_cancel_cnt));
    end else if (data_data_ok_i && (|data_cancel_cnt)) begin
        // 平稳期，收到一个废弃数据，计数减1
        data_cancel_cnt <= data_cancel_cnt - 2'd1;
    end
end

always @(posedge clk_i) begin
    if (data_data_ok_i) begin
        cached_data <= data_sram_rdata_i;
    end
end

always @(posedge clk_i) begin
    if (reset_i | flush_all_i) begin
        cached_data_ok <= 1'b0;
    end else if (mem_to_wb_valid_o & wb_allowin_i) begin
        cached_data_ok <= 1'b0;
    end else if (valid_data_ok) begin
        cached_data_ok <= 1'b1;
    end
end

always @(posedge clk_i) begin
    if (reset_i | flush_all_i) begin
        reg_valid <= 1'b0;
    end else if(mem_allowin_o) begin
        reg_valid <= valid_i;
    end
end

always @(posedge clk_i) begin
    if(mem_allowin_o && valid_i) begin
        reg_pc           <= pc_i;
        reg_gr_we        <= gr_we_i;
        reg_csr_we       <= csr_we_i;
        reg_csr_wnum     <= csr_wnum_i;
        reg_csr_result   <= csr_result_i;
        reg_csr_mask     <= csr_mask_i;
        reg_res_from_mem <= res_from_mem_i;
        reg_ex_result    <= ex_result_i;
        reg_dest         <= dest_i;
        reg_mem_en       <= mem_en_i;
        reg_mem_size     <= mem_size_i;
        reg_mem_sign_ext <= mem_sign_ext_i;
        reg_is_exc       <= is_exc_i;
        reg_exc_ecode    <= exc_ecode_i;
        reg_is_ertn      <= is_ertn_i;
        reg_wb_vaddr     <= wb_vaddr_i;
    end
end

// 根据地址低两位选择字节
assign byte_data = ({8{reg_ex_result[1:0] == 2'b00}} & real_rdata[ 7: 0]) |
                   ({8{reg_ex_result[1:0] == 2'b01}} & real_rdata[15: 8]) |
                   ({8{reg_ex_result[1:0] == 2'b10}} & real_rdata[23:16]) |
                   ({8{reg_ex_result[1:0] == 2'b11}} & real_rdata[31:24]) ;

// 根据地址第1位选择半字
assign half_data = reg_ex_result[1] ? real_rdata[31:16] : real_rdata[15:0];

// 根据reg_mem_size进行数据对齐与扩展
// reg_mem_size[0]: Byte | reg_mem_size[1]: Half | reg_mem_size[2]: Word
assign mem_result = 
    ({32{reg_mem_size[0]}} & {{24{reg_mem_sign_ext & byte_data[ 7]}}, byte_data}) |
    ({32{reg_mem_size[1]}} & {{16{reg_mem_sign_ext & half_data[15]}}, half_data}) |
    ({32{reg_mem_size[2]}} & real_rdata);

// mem级流水只负责把读取的数据转发给下一级（逻辑上），对sram的操作由上一级ex进行
// 实际上，还需要通过mem_allowin对上一级ex流水线进行控制
// 具体表现为如果后面流水阻塞，需要通过控制信号保证对sram的操作仅执行一次
// 对sram的操作应发生在ex_to_mem_valid拉高的那一个时刻，即ex流水转向mem流水的时刻
assign write_result_o = reg_res_from_mem ? mem_result : reg_ex_result; // 写regfile
assign write_csr_o    = reg_csr_result; // 写csr

// 中转信号
assign pc_o           = reg_pc;
assign gr_we_o        = reg_gr_we;
// 因为csr_we_o同时也做ID阶段的阻塞控制信号，所以这里不判断是否valid的话就会死锁
assign csr_we_o       = reg_csr_we && reg_valid;
assign csr_wnum_o     = reg_csr_wnum;
assign csr_mask_o     = reg_csr_mask;

// 如果不是valid，就释放dest，防止死锁
assign dest_o         = reg_valid ? reg_dest : 5'd0;
// 不需要判断reg_gr_we，已在ID阶段处理，如果不需要写入此处dest_0已经被设定为5'd0了
// assign dest_o         = reg_valid && reg_gr_we ? reg_dest : 5'd0;

// mem级流水不会触发异常
assign is_exc_o    = reg_is_exc;
assign exc_ecode_o = reg_exc_ecode;
assign is_ertn_o   = reg_is_ertn;
assign wb_vaddr_o  = reg_wb_vaddr;

assign mem_allowin_o = !reg_valid || (mem_ready_go && wb_allowin_i);
assign mem_to_wb_valid_o = reg_valid && mem_ready_go;

endmodule