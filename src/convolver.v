`timescale 1ns / 1ps
// `define FIXED_POINT 1

module convolver #(
    parameter n = 9'h00a,   // activation map size
    parameter k = 9'h003,   // kernel size
    parameter s = 1,        // stride
    parameter N = 16,       // total bit width
    parameter Q = 12        // bumber of fractional bits in case of fixed point representation
) (
    input wire clk,
    input wire ce,
    input wire global_rst,
    input wire [N-1:0] activation,
    input wire [(k*k)*16-1:0] weights,
    output wire [N-1:0] conv_op,
    output wire valid_conv,
    output wire end_conv
);
    
    reg [31:0] count, count2, count3, row_count;
    reg en1, en2, en3;
    wire [N-1:0] weight [0:k*k-1];
    wire [N-1:0] tmp [k*k+1:0];
    wire conv_vld;
    reg conv_vld_d1;

    // because of verilog does not allow us to pass multi-dimensional arrays as parameters
    // we breake our weights into separate variables
    // 将多维数组拆开
    generate
        genvar l;
        for(l=0; l<k*k; l=l+1) begin
            assign weight[l][N-1:0] = weights[N*l+:N];
        end
    endgenerate


    // 生成MAC
    // variable_shift_reg用于跳过当前行特征图没有被卷积核覆盖的部分，相当于打了n-k拍
    assign tmp[0] = 'd0;
    generate
        genvar i;
        for(i=0; i<k*k; i=i+1) begin : MAC
            if((i+1)%k == 0) begin                  // end of the row
                if(i == k*k-1) begin                // end of the convolver
                    mac_manual #(.N(N), .Q(Q)) mac( // implements a*b+c
                        .clk(clk),                  // input clk
                        .ce(ce),                    // input ce
                        .sclr(global_rst),          // input sclr
                        .a(activation),             // activation input [N-1 : 0] a
                        .b(weight[i]),              // weight input [N-1 : 0] b
                        .c(tmp[i]),                 // previous mac sum input [N-1 : 0] c
                        .p(conv_op)                 // output [N-1 : 0] p
                    );
                end
                else begin
                    wire [N-1:0] tmp2;
                    mac_manual #(.N(N), .Q(Q)) mac( // make a mac unit
                        .clk(clk),
                        .ce(ce),
                        .sclr(global_rst),
                        .a(activation),
                        .b(weight[i]),
                        .c(tmp[i]),
                        .p(tmp2)
                    );  
                    variable_shift_reg #(.WIDTH(N), .SIZE(n-k)) SR(
                        .d(tmp2),                   // input  d
                        .clk(clk),                  // input clk
                        .ce(ce),                    // input ce
                        .rst(global_rst),           // input sclr
                        .out(tmp[i+1])              // output  q
                    );
                end
            end
            else begin
                mac_manual #(.N(N), .Q(Q)) mac2(
                    .clk(clk),
                    .ce(ce),
                    .sclr(global_rst),
                    .a(activation),
                    .b(weight[i]),
                    .c(tmp[i]),
                    .p(tmp[i+1])
                );
            end
        end
    endgenerate



    // The following logic generates the 'valid_conv' and 'end_conv' output signals.
    // 生成valid_conv和end_conv信号
    // count用于记录时钟周期，count2用于记录卷积输出，count3用于记录无效卷积输出，row_count用于记录行数
    // 流水线需要(k-1)*n+k-1个周期。在窗口移动到输入的特定行之后，它继续换行到下一行，从而创建无效的输出
    // en1表示完成了流水线的全部周期（第一个输出），en3表示其余情况
    always @(posedge clk) begin
        if(global_rst) begin
            count <= 0;                         // master counter: counts the clock cycles
            count2 <= 0;                        // counts the valid convolution outputs
            count3 <= 0;                        // counts the number of invalid convolutions where the kernel wraps around the next row of inputs.
            row_count <= 0;                     // counts the number of rows of the output.  
            en1 <= 0;
            en2 <= 1;
            en3 <= 0;
        end
        else if(ce) begin
            if(count == (k-1)*n+k-1) begin      // time taken for the pipeline to fill up is (k-1)*n+k-1
                en1 <= 1'b1;
                count <= count + 1'b1;
            end
            else begin 
                count <= count + 1'b1;
            end
        end
        if(en1 && en2) begin
            if(count2 == n-k) begin
                count2 <= 0;
                en2 <= 0 ;
                row_count <= row_count + 1'b1;
            end
            else count2 <= count2 + 1'b1;
        end
        if(~en2) begin
            if(count3 == k-2) begin  // 这个k-2是什么意思？是和卷积核大小有关吗？（和特征图大小无关） en2在第一阶段过后和第二阶段之间的阶段为0
                count3<=0;
                en2 <= 1'b1;
            end
            else count3 <= count3 + 1'b1;
        end

        // one in every 's' convolutions becomes valid, also some exceptional cases handled for high when count2 = 0
        // one in every s convolutions becomes valid
        // some exceptional cases handled for high when count2 = 0
        if((((count2 + 1) % s == 0) && (row_count % s == 0))||(count3 == k-2)&&(row_count % s == 0)||(count == (k-1)*n+k-1)) begin
            en3 <= 1;  
        end
        else begin
            en3 <= 0;
        end
    end

    assign conv_vld = (en1 && en2 && en3);
    assign end_conv = (count>= n*n+2) ? 1'b1 : 1'b0;

    always@(posedge clk or posedge global_rst) begin
        if(global_rst)
            conv_vld_d1<= 0;
        else
            conv_vld_d1 <= conv_vld;
    end

    `ifdef FIXED_POINT
        assign valid_conv = conv_vld_d1;
    `else
        assign valid_conv = conv_vld;
    `endif

endmodule
