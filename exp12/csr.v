`include "csr_defines.vh"

module csr(
    input  wire        clk,
    input  wire        reset,

    input  wire        wb_pc,
    input  wire        wb_exc,
    input  wire        wb_ecode,
    input  wire        wb_esubcode,
    input  wire [ 7:0] hw_int_in,
    input  wire        ipi_int_in,
    input  wire        ertn_flush,

    input  wire        csr_we,
    input  wire [13:0] csr_wnum,
    input  wire [31:0] csr_wmask,
    input  wire [31:0] csr_wvalue,

    input  wire [13:0] csr_rnum;
    output wire [31:0] csr_rvalue
);

reg  [31:0] timer_cnt;

reg         csr_crmd_ie;
reg  [ 1:0] csr_crmd_plv;
wire        csr_crmd_da       = 1'b1;
wire        csr_crmd_pg       = 1'b0;
wire        csr_crmd_datf     = 2'b00;
wire        csr_crmd_datm     = 2'b00;
wire [31:0] csr_crmd_rvalue   = {23'd0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_plv, csr_crmd_ie};

reg         csr_prmd_pie;
reg  [ 1:0] csr_prmd_pplv;
wire [31:0] csr_prmd_rvalue   = {29'd0, csr_prmd_pplv, csr_prmd_pie};

reg  [12:0] csr_estat_is;
reg  [ 5:0] csr_estat_ecode;
reg  [ 8:0] csr_estat_esubcode;
wire [31:0] csr_estat_rvalue  = {1'd0, csr_estat_esubcode, csr_estat_ecode, 3'd0, csr_estat_is};

reg  [31:0] csr_era_pc;
wire [31:0] csr_era_rvalue    = csr_era_pc;

reg  [25:0] csr_eentry_va;
wire [31:0] csr_eentry_rvalue = {csr_eentry_va, 6'd0};

reg  [31:0] csr_save0_data;
wire [31:0] csr_save0_rvalue  = csr_save0_data;
reg  [31:0] csr_save1_data;
wire [31:0] csr_save1_rvalue  = csr_save1_data;
reg  [31:0] csr_save2_data;
wire [31:0] csr_save2_rvalue  = csr_save2_data;
reg  [31:0] csr_save3_data;
wire [31:0] csr_save3_rvalue  = csr_save3_data;

wire        csr_tcfg_en = 1'b0; //exp12暂不添加tcfg，此行代码为过渡用

assign csr_rvalue = {32{csr_rnum == `CSR_CRMD  }} & csr_crmd_rvalue
                  | {32{csr_rnum == `CSR_PRMD  }} & csr_prmd_rvalue
                  | {32{csr_rnum == `CSR_ESTAT }} & csr_estat_rvalue
                  | {32{csr_rnum == `CSR_ERA   }} & csr_era_rvalue
                  | {32{csr_rnum == `CSR_EENTRY}} & csr_eentry_rvalue
                  | {32{csr_rnum == `CSR_SAVE0 }} & csr_save0_rvalue
                  | {32{csr_rnum == `CSR_SAVE1 }} & csr_save1_rvalue
                  | {32{csr_rnum == `CSR_SAVE2 }} & csr_save2_rvalue
                  | {32{csr_rnum == `CSR_SAVE3 }} & csr_save3_rvalue;

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

always @(posedge clk) begin
    if(csr_we && csr_wnum==`CSR_EENTRY) begin
        csr_eentry_va <=   (csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA])
                         | (~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;)
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

endmodule