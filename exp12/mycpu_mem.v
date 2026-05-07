module mycpu_mem(
    input  wire        clk_i,
    input  wire        reset_i,

    // 输入
    input  wire [31:0] pc_i,
    input  wire        gr_we_i,
    input  wire        res_from_mem_i,
    input  wire [31:0] ex_result_i,
    input  wire [ 4:0] dest_i,
    input  wire [31:0] data_sram_rdata_i,
    input  wire [ 2:0] mem_size_i,
    input  wire        mem_sign_ext_i,

    // 给下一级的数据
    output wire [31:0] pc_o,
    output wire        gr_we_o,
    output wire [31:0] write_result_o,
    output wire [ 4:0] dest_o,

    // 控制信号
    input  wire        valid_i,
    input  wire        wb_allowin_i,
    output wire        mem_allowin_o,
    output wire        mem_to_wb_valid_o
);

wire       mem_ready_go = 1'b1;

wire [31:0] mem_result;
wire [ 3:0] mem_mask;
wire [ 7:0] byte_data;
wire [15:0] half_data;

reg [31:0] reg_pc;
reg        reg_valid;
reg        reg_gr_we;
reg        reg_res_from_mem;
reg [31:0] reg_ex_result;
reg [ 4:0] reg_dest;
reg [ 2:0] reg_mem_size;
reg        reg_mem_sign_ext;

always @(posedge clk_i) begin
    if (reset_i) begin
        reg_valid <= 1'b0;
    end else if(mem_allowin_o) begin
        reg_valid <= valid_i;
    end
end

always @(posedge clk_i) begin
    if(mem_allowin_o && valid_i) begin
        reg_pc           <= pc_i;
        reg_gr_we        <= gr_we_i;
        reg_res_from_mem <= res_from_mem_i;
        reg_ex_result    <= ex_result_i;
        reg_dest         <= dest_i;
        reg_mem_size     <= mem_size_i;
        reg_mem_sign_ext <= mem_sign_ext_i;
    end
end

// 根据地址低两位选择字节
assign byte_data = ({8{reg_ex_result[1:0] == 2'b00}} & data_sram_rdata_i[ 7: 0]) |
                   ({8{reg_ex_result[1:0] == 2'b01}} & data_sram_rdata_i[15: 8]) |
                   ({8{reg_ex_result[1:0] == 2'b10}} & data_sram_rdata_i[23:16]) |
                   ({8{reg_ex_result[1:0] == 2'b11}} & data_sram_rdata_i[31:24]) ;

// 根据地址第1位选择半字
assign half_data = reg_ex_result[1] ? data_sram_rdata_i[31:16] : data_sram_rdata_i[15:0];

// 根据reg_mem_size进行数据对齐与扩展
// reg_mem_size[0]: Byte | reg_mem_size[1]: Half | reg_mem_size[2]: Word
assign mem_result = 
    ({32{reg_mem_size[0]}} & {{24{reg_mem_sign_ext & byte_data[ 7]}}, byte_data}) |
    ({32{reg_mem_size[1]}} & {{16{reg_mem_sign_ext & half_data[15]}}, half_data}) |
    ({32{reg_mem_size[2]}} & data_sram_rdata_i);

// mem级流水只负责把读取的数据转发给下一级（逻辑上），对sram的操作由上一级ex进行
// 实际上，还需要通过mem_allowin对上一级ex流水线进行控制
// 具体表现为如果后面流水阻塞，需要通过控制信号保证对sram的操作仅执行一次
// 对sram的操作应发生在ex_to_mem_valid拉高的那一个时刻，即ex流水转向mem流水的时刻
assign write_result_o = reg_res_from_mem ? mem_result : reg_ex_result;

// 中转信号
assign pc_o           = reg_pc;
assign gr_we_o        = reg_gr_we;

// 如果不是valid，就释放dest，防止死锁
assign dest_o         = reg_valid ? reg_dest : 5'd0;
// 不需要判断reg_gr_we，已在ID阶段处理，如果不需要写入此处dest_0已经被设定为5'd0了
// assign dest_o         = reg_valid && reg_gr_we ? reg_dest : 5'd0;

assign mem_allowin_o = !reg_valid || (mem_ready_go && wb_allowin_i);
assign mem_to_wb_valid_o = reg_valid && mem_ready_go;

endmodule