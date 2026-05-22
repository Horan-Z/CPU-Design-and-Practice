module div (
    input  wire        clk,
    input  wire        reset,
    
    input  wire        div_start,
    output wire        div_done,
    
    input  wire [ 3:0] div_op,
    input  wire [31:0] div_src1,
    input  wire [31:0] div_src2,
    output wire [31:0] div_result
);

    wire op_is_signed = div_op[0] | div_op[2];
    wire op_is_rem    = div_op[2] | div_op[3];
    wire sign_src1    = div_src1[31];
    wire sign_src2    = div_src2[31];

    // 只需要两个状态
    localparam STATE_IDLE = 1'b0;
    localparam STATE_CALC = 1'b1;

    reg state;
    reg [4:0] count; 

    reg [31:0] reg_q;
    reg [31:0] reg_r;
    reg [31:0] reg_m;
    
    reg sign_q_res, sign_r_res, is_rem_res;

    // 核心计算逻辑
    wire [31:0] r_shifted = {reg_r[30:0], reg_q[31]}; 
    wire [32:0] sub_res   = {1'b0, r_shifted} - {1'b0, reg_m};
    wire        enough    = ~sub_res[32]; 

    wire [31:0] next_r    = enough ? sub_res[31:0] : r_shifted;
    wire [31:0] next_q    = {reg_q[30:0], enough};

    assign div_done = (state == STATE_CALC) && (count == 5'd0);

    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            // 其他数据不复位
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (div_start) begin
                        state <= STATE_CALC;
                        count <= 5'd31; 
                        reg_q <= (op_is_signed && sign_src1) ? (~div_src1 + 1'b1) : div_src1;
                        reg_m <= (op_is_signed && sign_src2) ? (~div_src2 + 1'b1) : div_src2;
                        reg_r <= 32'd0; 
                        sign_q_res <= op_is_signed & (sign_src1 ^ sign_src2);
                        sign_r_res <= op_is_signed & sign_src1;
                        is_rem_res <= op_is_rem;
                    end
                end

                STATE_CALC: begin
                    reg_r <= next_r;
                    reg_q <= next_q;
                    
                    if (count == 5'd0) begin
                        state <= STATE_IDLE; 
                    end else begin
                        count <= count - 1'b1;
                    end
                end
            endcase
        end
    end

    wire [31:0] current_q = div_done ? next_q : reg_q;
    wire [31:0] current_r = div_done ? next_r : reg_r;

    wire [31:0] final_q = sign_q_res ? (~current_q + 1'b1) : current_q;
    wire [31:0] final_r = sign_r_res ? (~current_r + 1'b1) : current_r;

    assign div_result = is_rem_res ? final_r : final_q;

endmodule