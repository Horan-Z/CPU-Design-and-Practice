module mycpu_preif(
    input  wire        clk_i,
    input  wire        reset_i,

    // 输入
    input  wire        br_taken_i,
    input  wire [31:0] br_target_i,
    input  wire        br_stall_i,
    input  wire        ertn_flush_i,
    input  wire        flush_all_i,
    input  wire [31:0] exc_entry_i,
    input  wire [31:0] exc_rtn_addr_i,

    // 给下一级的数据
    output wire [31:0] pc_o,

    // inst_ram读信号
    output wire        inst_sram_req_o,
    output wire [31:0] inst_sram_addr_o,
    input  wire        inst_addr_ok_i,

    // 控制信号
    input  wire        if_allowin_i,
    output wire        pre_to_if_valid_o
);

wire        pre_ready_go = (inst_sram_req_o & inst_addr_ok_i) | req_done | ~pc_aligned;

reg  [31:0] pc;
reg         req_done;

always @(posedge clk_i) begin
    if (reset_i) begin
        pc <= 32'h1c000000;
    end else if (ertn_flush_i) begin
        pc <= exc_rtn_addr_i;
    end else if (flush_all_i) begin
        pc <= exc_entry_i;
    end else if (br_taken_i) begin
        pc <= br_target_i;
    end else if (pre_ready_go & if_allowin_i & !br_stall_i) begin
        pc <= pc + 32'h4;
    end
end

always @(posedge clk_i) begin
    if (reset_i | ertn_flush_i | flush_all_i | br_taken_i) begin
        req_done <= 1'b0;
    end else if (pre_ready_go & if_allowin_i & !br_stall_i) begin
        req_done <= 1'b0;
    end else if (inst_sram_req_o & inst_addr_ok_i) begin
        req_done <= 1'b1;
    end
end

// 非对齐时取消读使能，但是不进行标记，因为preif不算流水线阶段
assign pc_aligned = (pc[1:0] == 2'b00);
assign inst_sram_req_o  = ~reset_i & pc_aligned & ~req_done & if_allowin_i & !br_stall_i & !flush_all_i & !ertn_flush_i;
assign inst_sram_addr_o = pc;
assign pc_o             = pc;

// 确认跳转的当前周期的pc还是上一周期的nextpc，即seq_pc
// 需等一周期pc才会变成br_target_i
assign pre_to_if_valid_o = pre_ready_go & !ertn_flush_i & !flush_all_i & !br_stall_i;

endmodule