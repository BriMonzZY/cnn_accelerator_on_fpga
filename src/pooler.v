`timescale 1ns / 1ps

module pooler #(
    parameter m = 9'h00c,  // size of input image/activation map (post convolution)
    parameter p = 9'h003,  // size of pooling window
    parameter N = 16,  // total bitwidth of data
    parameter Q = 12,  // number of fractional bits in the Fixed Point representation
    parameter ptype = 1, // ptype = 0-> average pooling, 1 -> max pooling
    parameter p_sqr_inv = 16'b0000010000000000  // this parameter is needed in average pooling case where the sum is divided by p**2.
                                                // It needs to be supplied manually and should be equal to (1/p)^2 in whatever the
                                                // (Q,N) format is being used.
) (
    input clk,
    input ce,
    input master_rst,
    input [N-1:0] data_in,
    output [N-1:0] data_out,
    output valid_op, // output signal to indicate the valid output
    output end_op   // output signal to indicate when all the valid outputs have been produced for that particular input matrix
);

    wire rst_m, load_sr, global_rst;  // op_en,pause_ip,
    wire [1:0] sel;
    wire [N-1:0] comp_op;
    wire [N-1:0] sr_op;
    wire [N-1:0] max_reg_op;
    wire [N-1:0] div_op;
    wire ovr;
    wire [N-1:0] mux_out;
    //reg [N-1:0] temp;

    // This block is the brains of this pooling unit. It generates 
    // the various signals needed to control all the other blocks 
    control_logic2 #(
        m,p
    ) log (
	    .clk(clk),
	    .master_rst(master_rst),
	    .ce(ce),
	    .sel(sel),
	    .rst_m(rst_m),
	    .op_en(valid_op),
	    .load_sr(load_sr),
	    .global_rst(global_rst),
	    .end_op(end_op)
    );
    
    comparator2 #(
        .N(N),
        .ptype(ptype)
    ) cmp (
        .ce(ce),         
	    .ip1(data_in),
	    .ip2(mux_out),
	    .comp_op(comp_op)
    );
  
    // A simple register to hold the current maximum/sum value. It can also be reset to zero
    max_reg #(
        .N(N)
    ) m1 (               
    	.clk(clk),
    	.ce(ce),
	    .din(comp_op),
	    .rst_m(rst_m),
	    .master_rst(master_rst),
	    .reg_op(max_reg_op)
    );
 
    variable_shift_reg #(
        .WIDTH(N),
        .SIZE((m/p))
    ) SR (
        .d(comp_op),                 
        .clk(clk),                 
        .ce(load_sr),                 
        .rst(global_rst && master_rst),         
        .out(sr_op)             
    );

    // the multiplexer that controls one input of the comparator (refer post title image)
    input_mux #(
        .N(N)
    ) mux (
        .ip1(sr_op),
        .ip2(max_reg_op),
        .sel(sel),
        .op(mux_out)
    );

    qmult #(N,Q) mul (clk,rst_m,max_reg_op,p_sqr_inv,div_op,ovr); 

    assign data_out = ptype ? max_reg_op : div_op; //for average pooling, we output the sum divided by p**2 

endmodule