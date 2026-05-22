module mycpu_top(
    input  wire        clk,
    input  wire        resetn,

    // 读请求通道
    output wire [ 3:0] arid,
    output wire [31:0] araddr,
    output wire [ 7:0] arlen,
    output wire [ 2:0] arsize,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot,
    output wire        arvalid,
    input  wire        arready,

    // 读响应通道
    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    // 写请求通道
    output wire [ 3:0] awid,
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,

    // 写数据通道
    output wire [ 3:0] wid,
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,

    // 写响应通道
    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready,

    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg         reset;
always @(posedge clk) reset <= ~resetn;

wire        inst_sram_req;
wire        inst_sram_wr;
wire [ 1:0] inst_sram_size;
wire [ 3:0] inst_sram_wstrb;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_wdata;
wire        inst_sram_addr_ok;
wire        inst_sram_data_ok;
wire [31:0] inst_sram_rdata;

wire        data_sram_req;
wire        data_sram_wr;
wire [ 1:0] data_sram_size;
wire [ 3:0] data_sram_wstrb;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire        data_sram_addr_ok;
wire        data_sram_data_ok;
wire [31:0] data_sram_rdata;

assign inst_sram_wr    = 1'b0;       // 指令 SRAM 永远只读
assign inst_sram_size  = 2'b10;      // 每次取指为 1 个字（4字节 = 32bit）
assign inst_sram_wstrb = 4'b0000;    // 无写掩码
assign inst_sram_wdata = 32'b0;      // 无写数据
assign data_sram_wr = |data_sram_wstrb;
assign data_sram_size  = 2'b10;

sram_to_axi u_sram_to_axi (
    .clk                (clk               ),
    .resetn             (resetn            ),

    // CPU 侧接口
    .inst_sram_req      (inst_sram_req     ),
    .inst_sram_wr       (inst_sram_wr      ),
    .inst_sram_size     (inst_sram_size    ),
    .inst_sram_wstrb    (inst_sram_wstrb   ),
    .inst_sram_addr     (inst_sram_addr    ),
    .inst_sram_wdata    (inst_sram_wdata   ),
    .inst_sram_addr_ok  (inst_sram_addr_ok ),
    .inst_sram_data_ok  (inst_sram_data_ok ),
    .inst_sram_rdata    (inst_sram_rdata   ),

    .data_sram_req      (data_sram_req     ),
    .data_sram_wr       (data_sram_wr      ),
    .data_sram_size     (data_sram_size    ),
    .data_sram_wstrb    (data_sram_wstrb   ),
    .data_sram_addr     (data_sram_addr    ),
    .data_sram_wdata    (data_sram_wdata   ),
    .data_sram_addr_ok  (data_sram_addr_ok ),
    .data_sram_data_ok  (data_sram_data_ok ),
    .data_sram_rdata    (data_sram_rdata   ),

    // 总线侧接口
    .arid               (arid              ),
    .araddr             (araddr            ),
    .arlen              (arlen             ),
    .arsize             (arsize            ),
    .arburst            (arburst           ),
    .arlock             (arlock            ),
    .arcache            (arcache           ),
    .arprot             (arprot            ),
    .arvalid            (arvalid           ),
    .arready            (arready           ),

    .rid                (rid               ),
    .rdata              (rdata             ),
    .rresp              (rresp             ),
    .rlast              (rlast             ),
    .rvalid             (rvalid            ),
    .rready             (rready            ),

    .awid               (awid              ),
    .awaddr             (awaddr            ),
    .awlen              (awlen             ),
    .awsize             (awsize            ),
    .awburst            (awburst           ),
    .awlock             (awlock            ),
    .awcache            (awcache           ),
    .awprot             (awprot            ),
    .awvalid            (awvalid           ),
    .awready            (awready           ),

    .wid                (wid               ),
    .wdata              (wdata             ),
    .wstrb              (wstrb             ),
    .wlast              (wlast             ),
    .wvalid             (wvalid            ),
    .wready             (wready            ),

    .bid                (bid               ),
    .bresp              (bresp             ),
    .bvalid             (bvalid            ),
    .bready             (bready            )
);

mycpu_preif u_preif(
    .clk_i             (clk               ),
    .reset_i           (reset             ),
    .br_taken_i        (br_taken          ),
    .br_target_i       (br_target         ),
    .br_stall_i        (br_stall          ),
    .ertn_flush_i      (ertn_flush        ),
    .flush_all_i       (flush_all         ),
    .exc_entry_i       (csr_eentry        ),
    .exc_rtn_addr_i    (csr_era           ),
    .pc_o              (pre_to_if_pc      ),
    .inst_sram_req_o   (inst_sram_req     ),
    .inst_sram_addr_o  (inst_sram_addr    ),
    .inst_addr_ok_i    (inst_sram_addr_ok ),
    .if_allowin_i      (if_allowin        ),
    .pre_to_if_valid_o (pre_to_if_valid   )
);

wire        if_allowin;
wire        pre_to_if_valid;
wire [31:0] pre_to_if_pc;
wire        br_taken;
wire [31:0] br_target;
wire        br_stall;

mycpu_if u_if(
    .clk_i             (clk               ),
    .reset_i           (reset             ),
    .flush_all_i       (flush_all         ),
    .br_taken_i        (br_taken          ),
    .pc_i              (pre_to_if_pc      ),
    .inst_sram_rdata_i (inst_sram_rdata   ),
    .if_data_ok_i      (inst_sram_data_ok ),
    .inst_o            (if_to_id_inst     ),
    .pc_o              (if_to_id_pc       ),
    .is_exc_o          (if_to_id_is_exc   ),
    .exc_ecode_o       (if_to_id_exc_code ),
    .valid_i           (pre_to_if_valid   ),
    .id_allowin_i      (id_allowin        ),
    .if_allowin_o      (if_allowin        ), 
    .if_to_id_valid_o  (if_to_id_valid    )
);

wire [31:0] if_to_id_pc;
wire [31:0] if_to_id_inst;
wire        if_to_id_is_exc;
wire [ 5:0] if_to_id_exc_code;
wire        if_to_id_valid;
wire        id_allowin;

mycpu_id u_id(
    .clk_i            (clk                   ),
    .reset_i          (reset                 ),
    .flush_all_i      (flush_all             ),
    .pc_i             (if_to_id_pc           ),
    .inst_i           (if_to_id_inst         ),
    .is_exc_i         (if_to_id_is_exc       ),
    .exc_ecode_i      (if_to_id_exc_code     ),
    .has_int_i        (has_int               ),
    .pc_o             (id_to_ex_pc           ),
    .gr_we_o          (id_to_ex_gr_we        ),
    .csr_we_o         (id_to_ex_csr_we       ),
    .csr_rd_o         (id_to_ex_csr_rd       ),
    .res_from_mem_o   (id_to_ex_res_from_mem ),
    .dest_o           (id_to_ex_dest         ),
    .ex_op_o          (id_to_ex_ex_op        ),
    .ex_src1_o        (id_to_ex_ex_src1      ),
    .ex_src2_o        (id_to_ex_ex_src2      ),
    .mem_en_o         (id_to_ex_mem_en       ),
    .mem_we_o         (id_to_ex_mem_we       ),
    .mem_size_o       (id_to_ex_mem_size     ),
    .mem_sign_ext_o   (id_to_ex_mem_sign_ext ),
    .rkd_value_o      (id_to_ex_rkd_value    ),
    .is_exc_o         (id_to_ex_is_exc       ),
    .exc_ecode_o      (id_to_ex_exc_ecode    ),
    .is_ertn_o        (id_to_ex_is_ertn      ),
    .csr_mask_o       (id_to_ex_csr_mask     ),
    .csr_num_o        (id_to_ex_csr_num      ),
    .br_taken_o       (br_taken              ),
    .br_target_o      (br_target             ),
    .br_stall_o       (br_stall              ),
    .rf_raddr1_o      (rf_raddr1             ),
    .rf_rdata1_i      (rf_rdata1             ),
    .rf_raddr2_o      (rf_raddr2             ),
    .rf_rdata2_i      (rf_rdata2             ),
    .ex_dest_i        (ex_to_mem_dest        ),
    .ex_write_reg_i   (ex_to_mem_ex_result   ),
    .mem_waiting_i    (mem_waiting           ),
    .mem_dest_i       (mem_to_wb_dest        ),
    .mem_write_reg_i  (mem_to_wb_write_result),
    .wb_dest_i        (wb_dest               ),
    .wb_write_reg_i   (rf_wdata              ),
    .ex_not_ready_i   (ex_to_id_ex_not_ready ),
    .ex_not_ready_o   (id_to_ex_ex_not_ready ),
    .ex_csr_we_i      (ex_to_mem_csr_we      ),
    .mem_csr_we_i     (mem_to_wb_csr_we      ),
    .wb_csr_we_i      (csr_we                ),
    .valid_i          (if_to_id_valid        ),
    .ex_allowin_i     (ex_allowin            ),
    .id_allowin_o     (id_allowin            ),
    .id_to_ex_valid_o (id_to_ex_valid        )
);

wire [31:0] id_to_ex_pc;
wire        id_to_ex_gr_we;
wire        id_to_ex_csr_we;
wire        id_to_ex_csr_rd;
wire [31:0] id_to_ex_csr_mask;
wire        id_to_ex_res_from_mem;
wire [ 4:0] id_to_ex_dest;
wire [20:0] id_to_ex_ex_op;
wire [31:0] id_to_ex_ex_src1;
wire [31:0] id_to_ex_ex_src2;
wire        id_to_ex_mem_en;
wire        id_to_ex_mem_we;
wire [ 2:0] id_to_ex_mem_size;
wire        id_to_ex_mem_sign_ext;
wire [31:0] id_to_ex_rkd_value;
wire        id_to_ex_is_exc;
wire [ 5:0] id_to_ex_exc_ecode;
wire        id_to_ex_is_ertn;
wire [13:0] id_to_ex_csr_num;
wire        id_to_ex_ex_not_ready;
wire        ex_to_id_ex_not_ready;
wire        ex_allowin;
wire        id_to_ex_valid;
wire        mem_waiting;

mycpu_ex u_ex(
    .clk_i             (clk                   ),
    .reset_i           (reset                 ),
    .flush_all_i       (flush_all             ),
    .pc_i              (id_to_ex_pc           ),
    .gr_we_i           (id_to_ex_gr_we        ),
    .csr_we_i          (id_to_ex_csr_we       ),
    .csr_wnum_i        (id_to_ex_csr_num      ),
    .csr_rd_i          (id_to_ex_csr_rd       ),
    // id阶段发出csr_rnum并保持，所以可直接在这里读
    .csr_result_i      (csr_rvalue            ),
    .csr_mask_i        (id_to_ex_csr_mask     ),
    .res_from_mem_i    (id_to_ex_res_from_mem ),
    .dest_i            (id_to_ex_dest         ),
    .ex_op_i           (id_to_ex_ex_op        ),
    .ex_src1_i         (id_to_ex_ex_src1      ),
    .ex_src2_i         (id_to_ex_ex_src2      ),
    .mem_en_i          (id_to_ex_mem_en       ),
    .mem_we_i          (id_to_ex_mem_we       ),
    .mem_size_i        (id_to_ex_mem_size     ),
    .mem_sign_ext_i    (id_to_ex_mem_sign_ext ),
    .rkd_value_i       (id_to_ex_rkd_value    ),
    .is_exc_i          (id_to_ex_is_exc       ),
    .exc_ecode_i       (id_to_ex_exc_ecode    ),
    .is_ertn_i         (id_to_ex_is_ertn      ),
    .stable_cnth_i     (stable_cnth           ),
    .stable_cntl_i     (stable_cntl           ),
    .pc_o              (ex_to_mem_pc          ),
    .gr_we_o           (ex_to_mem_gr_we       ),
    .csr_we_o          (ex_to_mem_csr_we      ),
    .csr_wnum_o        (ex_to_mem_csr_num     ),
    .csr_result_o      (ex_to_mem_csr_result  ),
    .csr_mask_o        (ex_to_mem_csr_mask    ),
    .res_from_mem_o    (ex_to_mem_res_from_mem),
    .dest_o            (ex_to_mem_dest        ),
    .mem_en_o          (ex_to_mem_mem_en      ),
    .ex_result_o       (ex_to_mem_ex_result   ),
    .mem_size_o        (ex_to_mem_mem_size    ),
    .mem_sign_ext_o    (ex_to_mem_mem_sign_ext),
    .is_exc_o          (ex_to_mem_is_exc      ),
    .exc_ecode_o       (ex_to_mem_exc_ecode   ),
    .is_ertn_o         (ex_to_mem_is_ertn     ),
    .wb_vaddr_o        (ex_to_mem_wb_vaddr    ),
    .ex_not_ready_i    (id_to_ex_ex_not_ready ),
    .ex_not_ready_o    (ex_to_id_ex_not_ready ),
    .mem_ertn_i        (mem_to_wb_is_ertn     ),
    .wb_ertn_i         (ertn_flush            ),
    .mem_is_exc_i      (mem_to_wb_is_exc      ),
    .wb_is_exc_i       (wb_exc                ),
    .valid_i           (id_to_ex_valid        ),
    .mem_allowin_i     (mem_allowin           ),
    .ex_allowin_o      (ex_allowin            ),
    .ex_to_mem_valid_o (ex_to_mem_valid       ),
    .ex_pending_o      (ex_to_mem_ex_pending  ),
    .data_sram_req_o   (data_sram_req         ),
    .data_sram_wstrb_o (data_sram_wstrb       ),
    .data_sram_addr_o  (data_sram_addr        ),
    .data_addr_ok_i    (data_sram_addr_ok     ),
    .data_sram_wdata_o (data_sram_wdata       )
);

wire [31:0] ex_to_mem_pc;
wire        ex_to_mem_gr_we;
wire        ex_to_mem_csr_we;
wire [13:0] ex_to_mem_csr_num;
wire [31:0] ex_to_mem_csr_result;
wire [31:0] ex_to_mem_csr_mask;
wire        ex_to_mem_res_from_mem;
wire [31:0] ex_to_mem_ex_result;
wire [ 4:0] ex_to_mem_dest;
wire        ex_to_mem_mem_en;
wire [ 2:0] ex_to_mem_mem_size;
wire        ex_to_mem_mem_sign_ext;
wire        ex_to_mem_is_exc;
wire [ 5:0] ex_to_mem_exc_ecode;
wire        ex_to_mem_is_ertn;
wire [31:0] ex_to_mem_wb_vaddr;
wire        mem_allowin;
wire        ex_to_mem_valid;
wire        ex_to_mem_ex_pending;

mycpu_mem u_mem(
    .clk_i             (clk                   ),
    .reset_i           (reset                 ),
    .flush_all_i       (flush_all             ),
    .pc_i              (ex_to_mem_pc          ),
    .gr_we_i           (ex_to_mem_gr_we       ),
    .csr_we_i          (ex_to_mem_csr_we      ),
    .csr_wnum_i        (ex_to_mem_csr_num     ),
    .csr_result_i      (ex_to_mem_csr_result  ),
    .csr_mask_i        (ex_to_mem_csr_mask    ),
    .res_from_mem_i    (ex_to_mem_res_from_mem),
    .ex_result_i       (ex_to_mem_ex_result   ),
    .dest_i            (ex_to_mem_dest        ),
    .mem_en_i          (ex_to_mem_mem_en      ),
    .data_sram_rdata_i (data_sram_rdata       ),
    .data_data_ok_i    (data_sram_data_ok     ),
    .mem_size_i        (ex_to_mem_mem_size    ),
    .mem_sign_ext_i    (ex_to_mem_mem_sign_ext),
    .is_exc_i          (ex_to_mem_is_exc      ),
    .exc_ecode_i       (ex_to_mem_exc_ecode   ),
    .is_ertn_i         (ex_to_mem_is_ertn     ),
    .wb_vaddr_i        (ex_to_mem_wb_vaddr    ),
    .pc_o              (mem_to_wb_pc          ),
    .gr_we_o           (mem_to_wb_gr_we       ),
    .csr_we_o          (mem_to_wb_csr_we      ),
    .csr_wnum_o        (mem_to_wb_csr_num     ),
    .mem_waiting_o     (mem_waiting           ),
    .write_result_o    (mem_to_wb_write_result),
    .write_csr_o       (mem_to_wb_write_csr   ),
    .csr_mask_o        (mem_to_wb_csr_mask    ),
    .dest_o            (mem_to_wb_dest        ),
    .is_exc_o          (mem_to_wb_is_exc      ),
    .exc_ecode_o       (mem_to_wb_exc_ecode   ),
    .is_ertn_o         (mem_to_wb_is_ertn     ),
    .wb_vaddr_o        (mem_to_wb_wb_vaddr    ),
    .valid_i           (ex_to_mem_valid       ),
    .ex_pending_i      (ex_to_mem_ex_pending  ),
    .wb_allowin_i      (wb_allowin            ),
    .mem_allowin_o     (mem_allowin           ),
    .mem_to_wb_valid_o (mem_to_wb_valid       )
);

wire [31:0] mem_to_wb_pc;
wire        mem_to_wb_gr_we;
wire        mem_to_wb_csr_we;
wire [13:0] mem_to_wb_csr_num;
wire [ 4:0] mem_to_wb_dest;
wire [31:0] mem_to_wb_write_result;
wire [31:0] mem_to_wb_write_csr;
wire [31:0] mem_to_wb_csr_mask;
wire        mem_to_wb_is_exc;
wire [ 5:0] mem_to_wb_exc_ecode;
wire        mem_to_wb_is_ertn;
wire [31:0] mem_to_wb_wb_vaddr;
wire        wb_allowin;
wire        mem_to_wb_valid;
wire [ 4:0] wb_dest;

mycpu_wb u_wb(
    .clk_i               (clk                   ),
    .reset_i             (reset                 ),
    .flush_all_i         (flush_all             ),
    .pc_i                (mem_to_wb_pc          ),
    .valid_i             (mem_to_wb_valid       ),
    .gr_we_i             (mem_to_wb_gr_we       ),
    .csr_we_i            (mem_to_wb_csr_we      ),
    .csr_wnum_i          (mem_to_wb_csr_num     ),
    .write_result_i      (mem_to_wb_write_result),
    .write_csr_i         (mem_to_wb_write_csr   ),
    .csr_mask_i          (mem_to_wb_csr_mask    ),
    .dest_i              (mem_to_wb_dest        ),
    .is_exc_i            (mem_to_wb_is_exc      ),
    .exc_ecode_i         (mem_to_wb_exc_ecode   ),
    .is_ertn_i           (mem_to_wb_is_ertn     ),
    .wb_vaddr_i          (mem_to_wb_wb_vaddr    ),
    .rf_we_o             (rf_we                 ),
    .rf_waddr_o          (rf_waddr              ),
    .rf_wdata_o          (rf_wdata              ),
    .dest_o              (wb_dest               ),
    .csr_we_o            (csr_we                ),
    .csr_wnum_o          (csr_wnum              ),
    .csr_mask_o          (csr_wmask             ),
    .csr_wvalue_o        (csr_wvalue            ),
    .wb_exc_o            (wb_exc                ),
    .wb_ecode_o          (wb_ecode              ),
    .wb_pc_o             (wb_pc                 ),
    .wb_vaddr_o          (wb_vaddr              ),
    .ertn_flush_o        (ertn_flush            ),
    .flush_all_o         (flush_all             ),
    .debug_wb_pc_o       (debug_wb_pc           ),
    .debug_wb_rf_we_o    (debug_wb_rf_we        ),
    .debug_wb_rf_wnum_o  (debug_wb_rf_wnum      ),
    .debug_wb_rf_wdata_o (debug_wb_rf_wdata     ),
    .wb_allowin_o        (wb_allowin            )
);

wire        flush_all;
wire        wb_exc;
wire [ 5:0] wb_ecode;
wire [31:0] wb_pc;
wire        ertn_flush;
wire [31:0] wb_vaddr;
wire [31:0] csr_rvalue;
wire        csr_we;
wire [13:0] csr_wnum;
wire [31:0] csr_wmask;
wire [31:0] csr_wvalue;
wire [31:0] csr_eentry;
wire [31:0] csr_era;
wire        has_int;

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

csr u_csr(
    .clk            (clk             ),
    .reset          (reset           ),
    .wb_pc          (wb_pc           ),
    .wb_exc         (wb_exc          ),
    .wb_ecode       (wb_ecode        ),
    // 根据la32r指令集手册v1.03，已经移除了唯一一个可能导致esubcode为0的异常
    // 所以现在esubcode永远为9'd0
    .wb_esubcode    (9'd0            ),
    // 硬件中断与核间中断暂不支持
    .hw_int_in      (8'd0            ),
    .ipi_int_in     (1'd0            ),
    .ertn_flush     (ertn_flush      ),
    .wb_vaddr       (wb_vaddr        ),
    .csr_we         (csr_we          ),
    .csr_wnum       (csr_wnum        ),
    .csr_wmask      (csr_wmask       ),
    .csr_wvalue     (csr_wvalue      ),
    .csr_rnum       (id_to_ex_csr_num),
    .csr_rvalue     (csr_rvalue      ),
    .csr_eentry     (csr_eentry      ),
    .csr_era        (csr_era         ),
    .has_int        (has_int         )
);

wire [31:0] stable_cnth;
wire [31:0] stable_cntl;

stable_counter u_scnt(
    .clk            (clk             ),
    .reset          (reset           ),
    .cnth           (stable_cnth     ),
    .cntl           (stable_cntl     )
);

endmodule
