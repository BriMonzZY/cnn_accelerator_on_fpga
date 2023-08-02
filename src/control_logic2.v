`timescale 1ns / 1ps



// The following are the various cases that arise as the pooling window moves over the input matrix
// each case requires a different kind of behaviour from the other modules in the pooler. 
// NOTE: here 'max value' => maximum of all the values withing the pooling window
// 以下是池化窗口在输入矩阵上移动时出现的各种情况，每种情况都需要池化器中其他模块的不同行为。
// 注意：此处的"最大值"=>池窗口中所有值的最大值

// 1. normal case : just store the max value in the register.  
// 2. end of one neighbourhood: store the max value to the shift register.
// 3. end of row: store the max value in the shift register and then load the max register from the shift register.
// 4. end of neighbourhood in the last row: make output valid and store the max value in the max register.
// 5. end of last neighbourhood of last row: make op valid and store the max value in the max register and then reset the entire module.
// 1.只需将最大值存储在寄存器中
// 2.一个邻域的末尾：将最大值存储到移位寄存器。
// 3.行末：将最大值存储在移位寄存器中，然后从移位寄存器加载最大寄存器。
// 4.最后一行邻域的末尾：使输出有效，并将最大值存储在最大寄存器中。
// 5.最后一行最后邻域的末尾：使op有效，并将最大值存储在最大寄存器中，然后重置整个模块。


//SIGNALS TO BE HANDLED IN EACH CASE
//CASE               1		 2		 3 	 	 4		 5 
//1. load _sr       low	    high	high	high	low			
//2. sel			low		low	   	high	high	low
//3. rst_m			low		high	low		low		low
//4. op_en			low		low		low		high	high
//5. global_rst		low		low		low		low		high

module control_logic2 (
    input clk,
    input master_rst,
    input ce,               // clock-enable
    output reg [1:0] sel,   // selection output that connects to the multiplexer input select lines
    output reg rst_m,       // signal to reset the maximum register
    output reg op_en,       // signal to tell the outside world when the output is valid
    output reg load_sr,     // signal to enable the clock for the shift register
    output reg global_rst,  // signal to reset all the othe modules except the control_logic
    output reg end_op       // signal to indicate end of all outputs for a particular input matrix
);

    parameter m = 9'h004;   // size of input matrix is m X m
    parameter p = 9'h002;   // size of the pooilng window is p X p
    integer row_count = 0;  // the entire module works based on the row and column counters
    integer col_count = 0;  // that tell it where exactly the window is at each clock cycle
    integer count = 0;      // the master counter that increments and resets row_count and col_count
    integer nbgh_row_count; // this counter keeps track of the number of neighbourhoods (pooling windows) completed

    always @(posedge clk) begin
        if(master_rst)begin
            sel <= 0;
            load_sr <= 0;
            rst_m <= 0;
            op_en <= 0;
            global_rst <= 0;
            end_op <= 0;
        end
        else begin
            if(((col_count+1)%p !=0)&&(row_count == p-1)&&(col_count == p*count + (p-2))&&ce) begin  // op_en
                op_en <= 1;
            end
            else begin
                op_en <= 0;
            end
            if(ce) begin
                if(nbgh_row_count == m/p) begin  // end_op
                    end_op <= 1;
                end
                else begin
                    end_op <= 0;
                end

                if(((col_count+1) % p != 0)&&(col_count == m-2)&&(row_count == p-1)) begin  // global_rst and pause_ip
                    global_rst <= 1;
                end
                else begin
                    global_rst <= 0;
                end

                if((((col_count+1) % p == 0)&&(count != m/p-1)&&(row_count != p-1))||((col_count == m-1)&&(row_count == p-1))) begin  // rst_m
                    rst_m <= 1;
                end
                else begin
                    rst_m <= 0;
                end

                if(((col_count+1) % p != 0)&&(col_count == m-2)&&(row_count == p-1)) begin
                    sel <= 2'b10;
                end
                else begin
                    if((((col_count) % p == 0)&&(count == m/p-1)&&(row_count != p-1))|| (((col_count) % p == 0)&&(count != m/p-1)&&(row_count == p-1))) begin     //sel
                        sel<=2'b01;
                    end
                    else begin
                        sel <= 2'b00;
                    end
                end

                if((((col_count+1) % p == 0)&&((count == m/p-1)))||((col_count+1) % p == 0)&&((count != m/p-1))) begin  // load_sr
                    load_sr <= 1;
                end
                else begin
                    load_sr <= 0;
                end
            end
        end
    end

    // counters
    always @(posedge clk) begin
        if(master_rst) begin
            row_count <=0;
            col_count <=32'hffffffff;
            count <=32'hffffffff;
            nbgh_row_count <=0;
        end
        else begin
            if(ce) begin
                if(global_rst) begin
                    row_count <=0;
                    col_count <=32'h0;//ffffffff;
                    count <=32'h0;//ffffffff;
                    nbgh_row_count <= nbgh_row_count + 1'b1; 
                end
                else begin
                    if(((col_count+1) % p == 0)&&(count == m/p-1)&&(row_count != p-1)) begin //  col_count and row_count
                        col_count <= 0;
                        row_count <= row_count + 1'b1;
                        count <=0;
                    end
                    else begin
                        col_count<=col_count+1'b1;
                        if(((col_count+1) % p == 0)&&(count != m/p-1)) begin
                            count <= count+ 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule
