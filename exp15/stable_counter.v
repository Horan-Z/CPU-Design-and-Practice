module stable_counter(
    input  wire        clk,
    input  wire        reset,

    output wire [31:0] cnth,
    output wire [31:0] cntl
);

reg [63:0] counter;
assign cnth = counter[63:32];
assign cntl = counter[31: 0];

always @(posedge clk) begin
    if (reset) begin
        counter <= 64'd0;
    end else begin
        counter <= counter + 64'b1;
    end
end

endmodule