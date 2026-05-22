module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg         reset;
always @(posedge clk) reset <= ~resetn;

mycpu_preif u_preif(
    .clk_i             (clk               ),
    .reset_i           (reset             ),
    .if_allowin_i      (if_allowin        ),
    .pre_to_if_valid_o (pre_to_if_valid   ),
    .br_taken_i        (br_taken          ),
    .br_target_i       (br_target         ),
    .inst_sram_en_o    (inst_sram_en      ),
    .inst_sram_addr_o  (inst_sram_addr    ),
    .pc_o              (pre_to_if_pc      )
);

wire        if_allowin;
wire        pre_to_if_valid;
wire [31:0] pre_to_if_pc;

mycpu_if u_if(
    .clk_i             (clk               ),
    .reset_i           (reset             ),
    .id_allowin_i      (id_allowin        ),
    .valid_i           (pre_to_if_valid   ),
    .pc_i              (pre_to_if_pc      ),
    .br_taken_cancel_i (br_taken_cancel   ),
    .if_to_id_valid_o  (if_to_id_valid    ),
    .if_allowin_o      (if_allowin        ),
    .inst_sram_rdata_i (inst_sram_rdata   ),
    .inst_o            (if_to_id_inst     ),
    .pc_o              (if_to_id_pc       )
);

wire [31:0] if_to_id_pc;
wire [31:0] if_to_id_inst;
wire        br_taken;
wire [31:0] br_target;
wire        br_taken_cancel;
wire        if_to_id_valid;
wire        id_allowin;

mycpu_id u_id(
    .clk_i            (clk                  ),
    .reset_i          (reset                ),
    .pc_i             (if_to_id_pc          ),
    .inst_i           (if_to_id_inst        ),
    .valid_i          (if_to_id_valid       ),
    .ex_allowin_i     (ex_allowin           ),
    .id_allowin_o     (id_allowin           ),
    .id_to_ex_valid_o (id_to_ex_valid       ),
    .pc_o             (id_to_ex_pc          ),
    .gr_we_o          (id_to_ex_gr_we       ),
    .res_from_mem_o   (id_to_ex_res_from_mem),
    .dest_o           (id_to_ex_dest        ),
    .alu_op_o         (id_to_ex_alu_op      ),
    .alu_src1_o       (id_to_ex_alu_src1    ),
    .alu_src2_o       (id_to_ex_alu_src2    ),
    .mem_en_o         (id_to_ex_mem_en      ),
    .mem_we_o         (id_to_ex_mem_we      ),
    .rkd_value_o      (id_to_ex_rkd_value   ),
    .br_taken_o       (br_taken             ),
    .br_target_o      (br_target            ),
    .br_taken_cancel_o(br_taken_cancel      ),
    .rf_raddr1_o      (rf_raddr1            ),
    .rf_rdata1_i      (rf_rdata1            ),
    .rf_raddr2_o      (rf_raddr2            ),
    .rf_rdata2_i      (rf_rdata2            ),
    .ex_dest_i        (ex_to_mem_dest       ),
    .mem_dest_i       (mem_to_wb_dest       ),
    .wb_dest_i        (wb_dest              )
);

wire [31:0] id_to_ex_pc;
wire        id_to_ex_gr_we;
wire        id_to_ex_res_from_mem;
wire [ 4:0] id_to_ex_dest;
wire [11:0] id_to_ex_alu_op;
wire [31:0] id_to_ex_alu_src1;
wire [31:0] id_to_ex_alu_src2;
wire        id_to_ex_mem_en;
wire [ 3:0] id_to_ex_mem_we;
wire [31:0] id_to_ex_rkd_value;
wire        ex_allowin;
wire        id_to_ex_valid;

mycpu_ex u_ex(
    .clk_i             (clk                   ),
    .reset_i           (reset                 ),
    .pc_i              (id_to_ex_pc           ),
    .gr_we_i           (id_to_ex_gr_we        ),
    .res_from_mem_i    (id_to_ex_res_from_mem ),
    .dest_i            (id_to_ex_dest         ),
    .alu_op_i          (id_to_ex_alu_op       ),
    .alu_src1_i        (id_to_ex_alu_src1     ),
    .alu_src2_i        (id_to_ex_alu_src2     ),
    .mem_en_i          (id_to_ex_mem_en       ),
    .mem_we_i          (id_to_ex_mem_we       ),
    .rkd_value_i       (id_to_ex_rkd_value    ),
    .pc_o              (ex_to_mem_pc          ),
    .gr_we_o           (ex_to_mem_gr_we       ),
    .res_from_mem_o    (ex_to_mem_res_from_mem),
    .dest_o            (ex_to_mem_dest        ),
    .alu_result_o      (ex_to_mem_alu_result  ),
    .valid_i           (id_to_ex_valid        ),
    .mem_allowin_i     (mem_allowin           ),
    .ex_allowin_o      (ex_allowin            ),
    .ex_to_mem_valid_o (ex_to_mem_valid       ),
    .data_sram_en_o    (data_sram_en          ),
    .data_sram_we_o    (data_sram_we          ),
    .data_sram_addr_o  (data_sram_addr        ),
    .data_sram_wdata_o (data_sram_wdata       )
);

wire [31:0] ex_to_mem_pc;
wire        ex_to_mem_gr_we;
wire        ex_to_mem_res_from_mem;
wire [31:0] ex_to_mem_alu_result;
wire [ 4:0] ex_to_mem_dest;
wire        mem_allowin;
wire        ex_to_mem_valid;

mycpu_mem u_mem(
    .clk_i             (clk                   ),
    .reset_i           (reset                 ),
    .pc_i              (ex_to_mem_pc          ),
    .gr_we_i           (ex_to_mem_gr_we       ),
    .res_from_mem_i    (ex_to_mem_res_from_mem),
    .alu_result_i      (ex_to_mem_alu_result  ),
    .dest_i            (ex_to_mem_dest        ),
    .data_sram_rdata_i (data_sram_rdata       ),
    .pc_o              (mem_to_wb_pc          ),
    .gr_we_o           (mem_to_wb_gr_we       ),
    .res_from_mem_o    (mem_to_wb_res_from_mem),
    .alu_result_o      (mem_to_wb_alu_result  ),
    .dest_o            (mem_to_wb_dest        ),
    .mem_result_o      (mem_result            ),
    .valid_i           (ex_to_mem_valid       ),
    .wb_allowin_i      (wb_allowin            ),
    .mem_allowin_o     (mem_allowin           ),
    .mem_to_wb_valid_o (mem_to_wb_valid       )
);

wire [31:0] mem_to_wb_pc;
wire        mem_to_wb_gr_we;
wire        mem_to_wb_res_from_mem;
wire [31:0] mem_to_wb_alu_result;
wire [ 4:0] mem_to_wb_dest;
wire [31:0] mem_result;
wire        wb_allowin;
wire        mem_to_wb_valid;
wire [ 4:0] wb_dest;

mycpu_wb u_wb(
    .clk_i               (clk                   ),
    .reset_i             (reset                 ),
    .pc_i                (mem_to_wb_pc          ),
    .valid_i             (mem_to_wb_valid       ),
    .gr_we_i             (mem_to_wb_gr_we       ),
    .res_from_mem_i      (mem_to_wb_res_from_mem),
    .mem_result_i        (mem_result            ),
    .alu_result_i        (mem_to_wb_alu_result  ),
    .dest_i              (mem_to_wb_dest        ),
    .rf_we_o             (rf_we                 ),
    .rf_waddr_o          (rf_waddr              ),
    .rf_wdata_o          (rf_wdata              ),
    .dest_o              (wb_dest               ),
    .debug_wb_pc_o       (debug_wb_pc           ),
    .debug_wb_rf_we_o    (debug_wb_rf_we        ),
    .debug_wb_rf_wnum_o  (debug_wb_rf_wnum      ),
    .debug_wb_rf_wdata_o (debug_wb_rf_wdata     ),
    .wb_allowin_o        (wb_allowin            )
);

wire [31:0] rf_raddr1;
wire [31:0] rf_raddr2;
wire [31:0] rf_rdata1;
wire [31:0] rf_rdata2;
wire        rf_we;
wire [31:0] rf_waddr;
wire [31:0] rf_wdata;

regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
);

endmodule
