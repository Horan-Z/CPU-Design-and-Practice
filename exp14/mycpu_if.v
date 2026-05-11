module mycpu_if(
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        flush_all_i,

    // 输入
    input  wire        br_taken_i,
    input  wire [31:0] pc_i,
    input  wire [31:0] inst_sram_rdata_i,
    input  wire        if_data_ok_i,

    // 给下一级的数据
    output wire [31:0] inst_o,
    output wire [31:0] pc_o,
    output wire        is_exc_o,
    output wire [ 5:0] exc_ecode_o,

    // 控制信号
    input  wire        valid_i,
    input  wire        id_allowin_i,
    output wire        if_allowin_o,
    output wire        if_to_id_valid_o
);

wire valid_data_ok = if_data_ok_i & (cancel_ok_cnt == 2'd0) & !flush_all_i & !br_taken_i;
wire if_ready_go   = cached_data_ok | valid_data_ok | is_exc_o;
wire pending_in    = reg_valid && !cached_data_ok && !(if_data_ok_i && cancel_ok_cnt == 2'd0) && !is_exc_o;

reg         reg_valid;
reg  [31:0] reg_pc;
reg  [31:0] cached_inst;
reg         cached_data_ok;
reg  [ 1:0] cancel_ok_cnt;

always @(posedge clk_i) begin
    if (reset_i) begin
        cancel_ok_cnt <= 2'd0;
    end else if (flush_all_i | br_taken_i) begin
        // 1.cnt应该累加
        // 2.有两个来源可以使cnt增加，preif和if各占1个
        // 3.如果触发的这个周期刚好匹配到cnt--的条件，则减1
        cancel_ok_cnt <= cancel_ok_cnt + pending_in + (valid_i & !exc_adef) - (if_data_ok_i & (|cancel_ok_cnt));
    end else if (if_data_ok_i & (|cancel_ok_cnt)) begin
        cancel_ok_cnt <= cancel_ok_cnt - 2'b1;
    end
end

always @(posedge clk_i) begin
    if (valid_data_ok) begin
        cached_inst <= inst_sram_rdata_i;
    end
end

always @(posedge clk_i) begin
    if (reset_i | flush_all_i | br_taken_i) begin
        cached_data_ok <= 1'b0;
    end else if (if_to_id_valid_o & id_allowin_i) begin
        cached_data_ok <= 1'b0;
    end else if (valid_data_ok) begin
        cached_data_ok <= 1'b1;
    end
end

always @(posedge clk_i) begin
    if (reset_i | flush_all_i | br_taken_i) begin
        reg_valid <= 1'b0;
    end else if(if_allowin_o) begin
        reg_valid <= valid_i;
        reg_pc    <= pc_i;
    end
end

assign inst_o           = cached_data_ok ? cached_inst : inst_sram_rdata_i;
assign pc_o             = reg_pc;

assign exc_adef         = (reg_pc[1:0] != 2'b00);
assign is_exc_o         = exc_adef;
assign exc_ecode_o      = {6{exc_adef}} & 6'h08;

assign if_allowin_o = !reg_valid || (if_ready_go && id_allowin_i);
assign if_to_id_valid_o = reg_valid & if_ready_go;

endmodule