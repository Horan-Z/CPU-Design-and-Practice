module mycpu_ex(
    input  wire        clk_i,
    input  wire        reset_i,

    input  wire [31:0] pc_i,
    input  wire        gr_we_i,
    input  wire        res_from_mem_i,
    input  wire [ 4:0] dest_i,
    input  wire [11:0] alu_op_i,
    input  wire [31:0] alu_src1_i,
    input  wire [31:0] alu_src2_i,
    input  wire        mem_en_i,
    input  wire [ 3:0] mem_we_i,
    input  wire [31:0] rkd_value_i,
    input  wire        ex_not_ready_i,

    output wire [31:0] pc_o,
    output wire        gr_we_o,
    output wire        res_from_mem_o,
    output wire [ 4:0] dest_o,
    output wire [31:0] alu_result_o,

    input  wire        valid_i,
    input  wire        mem_allowin_i,
    output wire        ex_allowin_o,
    output wire        ex_to_mem_valid_o,

    output wire        data_sram_en_o,
    output wire [ 3:0] data_sram_we_o,
    output wire [31:0] data_sram_addr_o,
    output wire [31:0] data_sram_wdata_o,
    output wire        ex_not_ready_o
);

wire       ex_ready_go = 1'b1;

wire [31:0] alu_result;

reg [31:0] reg_pc;
reg        reg_valid;
reg        reg_gr_we;
reg        reg_res_from_mem;
reg [ 4:0] reg_dest;
reg [11:0] reg_alu_op;
reg [31:0] reg_alu_src1;
reg [31:0] reg_alu_src2;
reg        reg_mem_en;
reg [ 3:0] reg_mem_we;
reg [31:0] reg_rkd_value;
reg        reg_ex_not_ready;

always @(posedge clk_i) begin
    if (reset_i) begin
        reg_valid <= 1'b0;
    end else if(ex_allowin_o) begin
        reg_valid <= valid_i;
    end
end

always @(posedge clk_i) begin
    if(ex_allowin_o && valid_i) begin
        reg_pc           <= pc_i;
        reg_gr_we        <= gr_we_i;
        reg_res_from_mem <= res_from_mem_i;
        reg_dest         <= dest_i;
        reg_alu_op       <= alu_op_i;
        reg_alu_src1     <= alu_src1_i;
        reg_alu_src2     <= alu_src2_i;
        reg_mem_en       <= mem_en_i;
        reg_mem_we       <= mem_we_i;
        reg_rkd_value    <= rkd_value_i;
        reg_ex_not_ready <= ex_not_ready_i;
    end
end

// 中转信号
assign pc_o           = reg_pc;
assign gr_we_o        = reg_gr_we;
assign res_from_mem_o = reg_res_from_mem;
// 如果不是valid，就释放dest，防止死锁
assign dest_o         = reg_valid && reg_gr_we ? reg_dest : 5'd0;
assign ex_not_ready_o = reg_ex_not_ready;

assign ex_allowin_o = !reg_valid || (ex_ready_go && mem_allowin_i);
assign ex_to_mem_valid_o = reg_valid && ex_ready_go;

assign data_sram_en_o    = reg_mem_en & ex_to_mem_valid_o & mem_allowin_i;
assign data_sram_we_o    = reg_mem_we & {4{ex_to_mem_valid_o & mem_allowin_i}};
assign data_sram_addr_o  = alu_result;
assign data_sram_wdata_o = reg_rkd_value;

assign alu_result_o    = alu_result;

alu u_alu(
    .alu_op     (reg_alu_op  ),
    .alu_src1   (reg_alu_src1),
    .alu_src2   (reg_alu_src2),
    .alu_result (alu_result  )
);

endmodule