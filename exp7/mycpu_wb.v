module mycpu_wb(
    input  wire        clk_i,
    input  wire        reset_i,

    input  wire [31:0] pc_i,
    input  wire        valid_i,

    input  wire        gr_we_i,
    input  wire        res_from_mem_i,
    input  wire [31:0] mem_result_i,
    input  wire [31:0] alu_result_i,
    input  wire [ 4:0] dest_i,

    output wire        rf_we_o,
    output wire [ 4:0] rf_waddr_o,
    output wire [31:0] rf_wdata_o,

    output wire [31:0] debug_wb_pc_o,
    output wire [ 3:0] debug_wb_rf_we_o,
    output wire [ 4:0] debug_wb_rf_wnum_o,
    output wire [31:0] debug_wb_rf_wdata_o,

    output wire        wb_allowin_o
);

wire       wb_ready_go = 1'b1;

reg [31:0] reg_pc;
reg        reg_valid;
reg        reg_gr_we;
reg        reg_res_from_mem;
reg [31:0] reg_mem_result;
reg [31:0] reg_alu_result;
reg [ 4:0] reg_dest;

always @(posedge clk) begin
    if (reset) begin
        reg_valid <= 1'b0;
    end else if(wb_allowin) begin
        // 这里也需要判断wb_allowin的原因是防止在本级处理完毕之前就关掉了valid信号
        reg_valid <= valid_i;
    end
end

// 不能把这个时序逻辑合并到上面变为【else if(wb_allowin && valid_i)】
// 会导致wb_valid卡在true无法更新
always @(posedge clk) begin
    if(wb_allowin && valid_i) begin
        reg_pc           <= pc_i;
        reg_gr_we        <= gr_we_i;
        reg_res_from_mem <= res_from_mem_i;
        reg_mem_result   <= mem_result_i;
        reg_alu_result   <= alu_result_i;
        reg_dest         <= dest_i;
    end
end

assign rf_we    = reg_gr_we && reg_valid;
assign rf_waddr = reg_dest;
assign rf_wdata = reg_res_from_mem ? reg_mem_result : reg_alu_result;

assign debug_wb_pc       = reg_pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

assign wb_allowin = !reg_valid || wb_ready_go;

endmodule