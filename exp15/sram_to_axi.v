module sram_to_axi(
    input  wire        clk,
    input  wire        resetn,

    // ==========================================
    // CPU 侧接口
    // ==========================================
    // 指令 SRAM 接口
    input  wire        inst_sram_req,
    input  wire        inst_sram_wr,
    input  wire [ 1:0] inst_sram_size,
    input  wire [ 3:0] inst_sram_wstrb,
    input  wire [31:0] inst_sram_addr,
    input  wire [31:0] inst_sram_wdata,
    output wire        inst_sram_addr_ok,
    output wire        inst_sram_data_ok,
    output wire [31:0] inst_sram_rdata,

    // 数据 SRAM 接口
    input  wire        data_sram_req,
    input  wire        data_sram_wr,
    input  wire [ 1:0] data_sram_size,
    input  wire [ 3:0] data_sram_wstrb,
    input  wire [31:0] data_sram_addr,
    input  wire [31:0] data_sram_wdata,
    output wire        data_sram_addr_ok,
    output wire        data_sram_data_ok,
    output wire [31:0] data_sram_rdata,

    // ==========================================
    // 总线侧接口
    // ==========================================
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
    output wire        bready
);

assign arlen    = 8'd0;
assign arburst  = 2'b01;
assign arlock   = 2'd0;
assign arcache  = 4'd0;
assign arprot   = 3'd0;

assign awid     = 4'd1;
assign awlen    = 8'd0;
assign awburst  = 2'b01;
assign awlock   = 2'd0;
assign awcache  = 4'd0;
assign awprot   = 3'd0;

assign wid      = 4'd1;
assign wlast    = 1'b1;

// ==========================================
// 读通道状态机 (处理 Inst Read 和 Data Read)
// ==========================================
localparam R_IDLE = 2'd0;
localparam R_AR   = 2'd1;
localparam R_R    = 2'd2;

reg [ 1:0] read_state;
reg        read_type;   // 0: Inst 读, 1: Data 读
reg [31:0] araddr_reg;
reg [ 2:0] arsize_reg;
reg [ 3:0] arid_reg;

wire rd_req_data = data_sram_req && !data_sram_wr;
wire rd_req_inst = inst_sram_req;

always @(posedge clk) begin
    if (!resetn) begin
        read_state <= R_IDLE;
        read_type  <= 1'b0;
    end else begin
        case (read_state)
            R_IDLE: begin
                // Data Read 优先级高
                if (rd_req_data && (write_state == W_IDLE)) begin 
                    read_state <= R_AR;
                    read_type  <= 1'b1;
                    araddr_reg <= data_sram_addr;
                    arsize_reg <= {1'b0, data_sram_size};
                    arid_reg   <= 4'd1;
                // 修改此处：只有当没有 Data 读请求时，才允许吃进 Inst 读请求
                end else if (rd_req_inst && !rd_req_data) begin 
                    read_state <= R_AR;
                    read_type  <= 1'b0;
                    araddr_reg <= inst_sram_addr;
                    arsize_reg <= {1'b0, inst_sram_size};
                    arid_reg   <= 4'd0;
                end
            end
            R_AR: begin
                if (arvalid && arready) begin
                    read_state <= R_R;
                end
            end
            R_R: begin
                if (rvalid && rready) begin
                    read_state <= R_IDLE;
                end
            end
        endcase
    end
end

// ==========================================
// 写通道状态机 (专职处理 Data Write)
// ==========================================
localparam W_IDLE = 2'd0;
localparam W_AW_W = 2'd1;
localparam W_B    = 2'd2;

reg [ 1:0] write_state;
reg [31:0] awaddr_reg;
reg [ 2:0] awsize_reg;
reg [31:0] wdata_reg;
reg [ 3:0] wstrb_reg;

// AXI 中 AW 和 W 通道是互相独立的，必须用两个标志位分别记录握手情况
reg aw_done;
reg w_done;

wire wr_req_data = data_sram_req && data_sram_wr;

always @(posedge clk) begin
    if (!resetn) begin
        write_state <= W_IDLE;
        aw_done     <= 1'b0;
        w_done      <= 1'b0;
    end else begin
        case (write_state)
            W_IDLE: begin
                if (wr_req_data && !data_read_busy) begin // 修改此处：增加互斥条件
                    write_state <= W_AW_W;
                    awaddr_reg  <= data_sram_addr;
                    awsize_reg  <= {1'b0, data_sram_size};
                    wdata_reg   <= data_sram_wdata;
                    wstrb_reg   <= data_sram_wstrb;
                    aw_done     <= 1'b0;
                    w_done      <= 1'b0;
                end
            end
            W_AW_W: begin
                if (awvalid && awready) aw_done <= 1'b1;
                if (wvalid && wready)   w_done  <= 1'b1;

                // 当两个通道都完成握手时（包含当拍同时完成的情况），进入等响应阶段
                if ((aw_done || (awvalid && awready)) &&
                    (w_done  || (wvalid  && wready ))) begin
                    write_state <= W_B;
                end
            end
            W_B: begin
                if (bvalid && bready) begin
                    write_state <= W_IDLE;
                end
            end
        endcase
    end
end

// ==========================================
// AXI 信号输出驱动
// ==========================================
// AR 读地址通道
assign arid    = arid_reg;
assign araddr  = araddr_reg;
assign arsize  = arsize_reg;
assign arvalid = (read_state == R_AR);

// R 读数据响应通道
assign rready  = (read_state == R_R);

// AW 写地址通道 (如果已经 done 了，必须立刻拉低 valid)
assign awaddr  = awaddr_reg;
assign awsize  = awsize_reg;
assign awvalid = (write_state == W_AW_W) && !aw_done;

// W 写数据通道
assign wdata   = wdata_reg;
assign wstrb   = wstrb_reg;
assign wvalid  = (write_state == W_AW_W) && !w_done;

// B 写响应通道
assign bready  = (write_state == W_B);

// ==========================================
// CPU 侧 SRAM 握手信号生成
// ==========================================

// addr_ok 生成：桥在 IDLE 状态时可以直接接收请求，给出组合逻辑的 addr_ok
// CPU 在下一拍会拉低 req，而桥在下一拍将请求锁存进寄存器并离开 IDLE，完美同步
assign inst_sram_addr_ok = (read_state == R_IDLE) && rd_req_inst && !rd_req_data;

// 判定当前读状态机是否正在处理【数据读】
wire data_read_busy      = (read_state != R_IDLE) && (read_type == 1'b1);

// 数据读必须等待写状态机空闲
wire data_read_addr_ok   = (read_state == R_IDLE) && rd_req_data && (write_state == W_IDLE);

// 数据写必须等待数据读空闲（补上 !data_read_busy）
wire data_write_addr_ok  = (write_state == W_IDLE) && wr_req_data && !data_read_busy;

assign data_sram_addr_ok = data_sram_wr ? data_write_addr_ok : data_read_addr_ok;

// data_ok 生成：当 AXI 返回 valid 响应时
assign inst_sram_data_ok = (read_state == R_R) && rvalid && rready && (read_type == 1'b0);

wire data_read_data_ok   = (read_state == R_R) && rvalid && rready && (read_type == 1'b1);
wire data_write_data_ok  = (write_state == W_B) && bvalid && bready;

// 因为上面加上了严格的互斥逻辑，读写绝对不会并发，所以这里直接按位或绝对安全
assign data_sram_data_ok = data_read_data_ok | data_write_data_ok;

// 读回数据广播，因为 data_ok 会通过状态精准发给对应的通道，所以直接共享 rdata 是安全的
assign inst_sram_rdata = rdata;
assign data_sram_rdata = rdata;

endmodule