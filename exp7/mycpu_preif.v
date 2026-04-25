module mycpu_preif(
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        if_allowin_i,
    output wire        pre_to_if_valid_o,

    input  wire        br_taken_i,
    input  wire [31:0] br_target_i,

    output wire        inst_sram_en_o,
    output wire [31:0] inst_sram_addr_o,

    output wire [31:0] pc_o
);

wire        pre_ready_go = 1'b1;

reg  [31:0] pc;
wire [31:0] seq_pc;
wire [31:0] nextpc;
wire        if_allowin;

assign seq_pc       = pc + 32'h4;
assign nextpc       = br_taken_i ? br_target_i : seq_pc;

always @(posedge clk_i) begin
    if (reset_i) begin
        pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end else if(if_allowin_i) begin
        pc <= nextpc;
    end
end

assign inst_sram_en_o   = ~reset_i;
assign inst_sram_addr_o = nextpc;
assign pc_o             = pc;

assign pre_to_if_valid_o = pre_ready_go;

endmodule