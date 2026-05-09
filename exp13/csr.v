`include "csr_defines.vh"

module csr(
    input  wire        clk,
    input  wire        reset,

    input  wire [31:0] wb_pc,
    input  wire        wb_exc,
    input  wire [ 5:0] wb_ecode,
    input  wire        wb_esubcode,
    input  wire [ 7:0] hw_int_in,
    input  wire        ipi_int_in,
    input  wire        ertn_flush,
    input  wire [31:0] wb_vaddr,

    input  wire        csr_we,
    input  wire [13:0] csr_wnum,
    input  wire [31:0] csr_wmask,
    input  wire [31:0] csr_wvalue,

    input  wire [13:0] csr_rnum,
    output wire [31:0] csr_rvalue,

    output wire [31:0] csr_eentry,
    output wire [31:0] csr_era,

    output wire        has_int
);

reg  [31:0] timer_cnt;
wire [31:0] tcfg_next_value;
assign tcfg_next_value =   (csr_wmask[31:0] & csr_wvalue[31:0])
                         | (~csr_wmask[31:0] & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en}); 

reg         csr_crmd_ie;
reg  [ 1:0] csr_crmd_plv;
wire        csr_crmd_da       = 1'b1;
wire        csr_crmd_pg       = 1'b0;
wire        csr_crmd_datf     = 2'b00;
wire        csr_crmd_datm     = 2'b00;
wire [31:0] csr_crmd_rvalue   = {23'd0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_plv, csr_crmd_ie};

reg         csr_prmd_pie;
reg  [ 1:0] csr_prmd_pplv;
wire [31:0] csr_prmd_rvalue   = {29'd0, csr_prmd_pie, csr_prmd_pplv};

reg  [12:0] csr_ecfg_lie;
wire [31:0] csr_ecfg_rvalue   = {19'd0, csr_ecfg_lie};

reg  [12:0] csr_estat_is;
reg  [ 5:0] csr_estat_ecode;
reg  [ 8:0] csr_estat_esubcode;
wire [31:0] csr_estat_rvalue  = {1'd0, csr_estat_esubcode, csr_estat_ecode, 3'd0, csr_estat_is};

reg  [31:0] csr_era_pc;
wire [31:0] csr_era_rvalue    = csr_era_pc;
assign      csr_era           = csr_era_rvalue;

reg  [31:0] csr_badv_vaddr;
wire [31:0] csr_badv_rvalue   = csr_badv_vaddr;

reg  [25:0] csr_eentry_va;
wire [31:0] csr_eentry_rvalue = {csr_eentry_va, 6'd0};
assign      csr_eentry        = csr_eentry_rvalue;

wire [31:0] csr_cpuid_rvalue  = {24'd0, 8'd0};

reg  [31:0] csr_save0_data;
wire [31:0] csr_save0_rvalue  = csr_save0_data;
reg  [31:0] csr_save1_data;
wire [31:0] csr_save1_rvalue  = csr_save1_data;
reg  [31:0] csr_save2_data;
wire [31:0] csr_save2_rvalue  = csr_save2_data;
reg  [31:0] csr_save3_data;
wire [31:0] csr_save3_rvalue  = csr_save3_data;

reg  [31:0] csr_tid_tid;
wire [31:0] csr_tid_rvalue    = csr_tid_tid;

reg         csr_tcfg_en;
reg         csr_tcfg_periodic;
reg  [29:0] csr_tcfg_initval;
wire [31:0] csr_tcfg_rvalue   = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

wire [31:0] csr_tval_rvalue   = timer_cnt[31:0];

wire        csr_ticlr_clr     = 1'b0;
wire [31:0] csr_ticlr_rvalue  = {31'd0, csr_ticlr_clr};

assign has_int = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && (csr_crmd_ie == 1'b1);

assign csr_rvalue = {32{csr_rnum == `CSR_CRMD  }} & csr_crmd_rvalue
                  | {32{csr_rnum == `CSR_PRMD  }} & csr_prmd_rvalue
                  | {32{csr_rnum == `CSR_ECFG  }} & csr_ecfg_rvalue
                  | {32{csr_rnum == `CSR_ESTAT }} & csr_estat_rvalue
                  | {32{csr_rnum == `CSR_ERA   }} & csr_era_rvalue
                  | {32{csr_rnum == `CSR_BADV  }} & csr_badv_rvalue
                  | {32{csr_rnum == `CSR_EENTRY}} & csr_eentry_rvalue
                  | {32{csr_rnum == `CSR_SAVE0 }} & csr_save0_rvalue
                  | {32{csr_rnum == `CSR_SAVE1 }} & csr_save1_rvalue
                  | {32{csr_rnum == `CSR_SAVE2 }} & csr_save2_rvalue
                  | {32{csr_rnum == `CSR_SAVE3 }} & csr_save3_rvalue
                  | {32{csr_rnum == `CSR_TID   }} & csr_tid_rvalue
                  | {32{csr_rnum == `CSR_TCFG  }} & csr_tcfg_rvalue
                  | {32{csr_rnum == `CSR_TVAL  }} & csr_tval_rvalue
                  | {32{csr_rnum == `CSR_TICLR }} & csr_ticlr_rvalue;

always @(posedge clk) begin
    if(reset) begin
        timer_cnt <= 32'hffffffff;
    end else if(csr_we && csr_wnum == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN]) begin
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};
    end else if(csr_tcfg_en && timer_cnt != 32'hffffffff) begin
        if(timer_cnt[31:0] == 32'b0 && csr_tcfg_periodic) begin
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        end else begin
            timer_cnt <= timer_cnt - 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(reset) begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
    end else if(wb_exc) begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
    end else if(ertn_flush) begin
        csr_crmd_plv <= csr_prmd_pplv;
        csr_crmd_ie  <= csr_prmd_pie;
    end else if(csr_we && csr_wnum == `CSR_CRMD) begin
        csr_crmd_plv <=   (csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV])
                        | (~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv);

        csr_crmd_ie  <=   (csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE])
                        | (~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie);
    end
end

always @(posedge clk) begin
    if(wb_exc) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie;
    end else if(csr_we && csr_wnum == `CSR_PRMD) begin
        csr_prmd_pplv <=   (csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV])
                         | (~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv);

        csr_prmd_pie  <=   (csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE])
                         | (~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie);
    end
end

always @(posedge clk) begin
    if(reset) begin
        csr_ecfg_lie <= 13'b0;
    end else if(csr_we && csr_wnum == `CSR_ECFG) begin
        csr_ecfg_lie <=   (csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_wvalue[`CSR_ECFG_LIE])
                        | (~csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_ecfg_lie);
    end
end

always @(posedge clk) begin
    if(reset) begin
        csr_estat_is[1:0] <= 2'b0;
    end else if(csr_we && csr_wnum == `CSR_ESTAT) begin
        csr_estat_is[1:0] <=   (csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10])
                             | (~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0]);
    end

    csr_estat_is[9:2] <= hw_int_in[7:0];
    csr_estat_is[10]  <= 1'b0;
        
    if(csr_tcfg_en && timer_cnt[31:0] == 32'b0) begin
        csr_estat_is[11] <= 1'b1;
    end else if(csr_we && csr_wnum == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR]) begin
        csr_estat_is[11] <= 1'b0;
    end

    csr_estat_is[12] <= ipi_int_in;
end

always @(posedge clk) begin
    if(wb_exc) begin
        csr_estat_ecode    <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

always @(posedge clk) begin
    if(wb_exc) begin
        csr_era_pc <= wb_pc;
    end else if(csr_we && csr_wnum == `CSR_ERA) begin
        csr_era_pc <=   (csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC])
                      | (~csr_wmask[`CSR_ERA_PC] & csr_era_pc);
    end
end

assign wb_ex_addr_err = wb_ecode == `ECODE_ADE || wb_ecode == `ECODE_ALE;
always @(posedge clk) begin
    if(wb_exc && wb_ex_addr_err) begin
        // la32r v1.03指令集手册中已明确移除ADEM异常
        csr_badv_vaddr <= wb_ecode == `ECODE_ADE ? wb_pc : wb_vaddr;
    end
end

always @(posedge clk) begin
    if(csr_we && csr_wnum==`CSR_EENTRY) begin
        csr_eentry_va <=   (csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA])
                         | (~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va);
    end
end

always @(posedge clk) begin
    if(csr_we && csr_wnum == `CSR_SAVE0) begin
        csr_save0_data <=   (csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA])
                          | (~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data);
    end
    
    if(csr_we && csr_wnum == `CSR_SAVE1) begin
        csr_save1_data <=   (csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA])
                          | (~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data);
    end
    
    if(csr_we && csr_wnum == `CSR_SAVE2) begin
        csr_save2_data <=   (csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA])
                          | (~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data);
    end
    
    if(csr_we && csr_wnum == `CSR_SAVE3) begin
        csr_save3_data <=   (csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA])
                          | (~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data);
    end
end

always @(posedge clk) begin
    if(reset) begin
        csr_tid_tid <= csr_cpuid_rvalue;
    end else if(csr_we && csr_wnum == `CSR_TID) begin
        csr_tid_tid <=   (csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID])
                       | (~csr_wmask[`CSR_TID_TID] & csr_tid_tid);
    end
end

always @(posedge clk) begin
    if(reset) begin
        csr_tcfg_en <= 1'b0;
    end else if(csr_we && csr_wnum == `CSR_TCFG) begin
        csr_tcfg_en <=   (csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN])
                       | (~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en);
    end
    
    if(csr_we && csr_wnum == `CSR_TCFG) begin
        csr_tcfg_periodic <=   (csr_wmask[`CSR_TCFG_PERIOD] & csr_wvalue[`CSR_TCFG_PERIOD])
                             | (~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic);
                             
        csr_tcfg_initval  <=   (csr_wmask[`CSR_TCFG_INITV] & csr_wvalue[`CSR_TCFG_INITV])
                             | (~csr_wmask[`CSR_TCFG_INITV] & csr_tcfg_initval);
    end
end

endmodule