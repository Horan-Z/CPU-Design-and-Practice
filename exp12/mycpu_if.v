module mycpu_if(
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        flush_all_i,

    // 输入
    input  wire        br_taken_cancel_i,
    input  wire [31:0] pc_i,
    input  wire [31:0] inst_sram_rdata_i,

    // 给下一级的数据
    output wire [31:0] inst_o,
    output wire [31:0] pc_o,

    // 控制信号
    input  wire        valid_i,
    input  wire        id_allowin_i,
    output wire        if_allowin_o,
    output wire        if_to_id_valid_o
);

wire        if_ready_go = 1'b1;

reg         reg_valid;
reg  [31:0] reg_pc; 
reg  [31:0] reg_inst;

always @(posedge clk_i) begin
    if (reset_i | flush_all_i) begin
        reg_valid <= 1'b0;
    end else if(if_allowin_o) begin
        reg_valid <= valid_i;
        reg_pc    <= pc_i;
        reg_inst  <= inst_sram_rdata_i;
    end else if(br_taken_cancel_i) begin
        reg_valid <= 1'b0;
    end
end

assign inst_o           = reg_inst;
assign pc_o             = reg_pc;

assign if_allowin_o = !reg_valid || (if_ready_go && id_allowin_i);
assign if_to_id_valid_o = reg_valid & if_ready_go;

endmodule