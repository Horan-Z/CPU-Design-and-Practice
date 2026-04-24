module mycpu_if(
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        id_allowin_i,
    output wire        if_to_id_valid_o,

    input  wire        br_taken_i,
    input  wire [31:0] br_target_i,

    output wire        inst_sram_en_o,
    output wire [31:0] inst_sram_addr_o,
    input  wire [31:0] inst_sram_rdata_i,

    output wire [31:0] inst_o,
    output wire [31:0] pc_o
);

wire        if_ready_go = 1'b1;

reg  [31:0] pc;
wire [31:0] seq_pc;
wire [31:0] nextpc;

assign seq_pc       = pc + 32'h4;
assign nextpc       = br_taken_i ? br_target_i : seq_pc;

always @(posedge clk_i) begin
    if (reset_i) begin
        pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if(id_allowin_i) begin
        pc <= nextpc;
    end
end

assign inst_sram_en_o   = ~reset_i;
assign inst_sram_addr_o = pc;
assign inst_o           = inst_sram_rdata_i;
assign pc_o             = pc;

assign if_to_id_valid_o = if_ready_go;

endmodule