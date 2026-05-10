module mul(
  input  wire [ 2:0] mul_op,
  input  wire [31:0] mul_src1,
  input  wire [31:0] mul_src2,
  output wire [31:0] mul_result
);

// 除了2号操作（inst_mulh_wu）均为signed乘法
wire is_signed = ~mul_op[2];

// 将 32 位操作数扩展为 33 位
wire [32:0] ext_src1 = {(is_signed & mul_src1[31]), mul_src1[31:0]};
wire [32:0] ext_src2 = {(is_signed & mul_src2[31]), mul_src2[31:0]};

// 统一进行 33 位有符号乘法，得到 66 位结果
wire [65:0] prod_66 = $signed(ext_src1) * $signed(ext_src2);

// 截取所需的结果
// 除了0号操作（inst_mul_w）结果均需要高位
assign mul_result = mul_op[0] ? prod_66[31:0] : prod_66[63:32];

endmodule