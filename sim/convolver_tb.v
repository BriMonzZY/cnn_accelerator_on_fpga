`timescale 1ns / 1ps

module convolver_tb();

	// Inputs
	reg clk;
	reg ce;
	// reg [143:0] weights;
    reg [400-1:0] weights;
	reg global_rst;
	reg [15:0] activation;

	// Outputs
	wire [31:0] conv_op;
	wire end_conv;
	wire valid_conv;
	integer i;
    parameter clkp = 40;

    initial begin
        // `ifdef FSDB
        //     $display("\n---use verdi---\n");
        //     $fsdbDumpfile("convolver_tb.fsdb");
        //     $fsdbDumpvars(0, convolver_tb);
        // `elsif IVERILOG
        //     $display("\n---use iverilog---\n");
        //     $dumpfile("convolver_tb.fst");
        //     $dumpvars(0, convolver_tb);
        // `else
        //     $display("\n---use dve---\n");
        //     $vcdpluson;
        //     $vcdplusmemon;
        // `endif
        $display("\n---use iverilog---\n");
        $dumpfile("convolver_tb.fst");
        $dumpvars(0, convolver_tb);
    end


	// Instantiate the Unit Under Test (UUT)
	convolver #(9'h006,9'h005,1) uut (
		.clk(clk), 
		.ce(ce), 
		.weights(weights), 
		.global_rst(global_rst), 
		.activation(activation), 
		.conv_op(conv_op), 
		.end_conv(end_conv), 
		.valid_conv(valid_conv)
	);

	initial begin
        // Initialize Inputs
        clk = 0;
        ce = 0;
        weights = 0;
        global_rst = 0;
        activation = 0;
        // Wait 100 ns for global reset to finish
        #100;
        clk = 0;
        ce = 0;
        weights = 0;
        activation = 0;
        global_rst =1;
        #50;
        global_rst =0;	
        #10;	
        ce=1;
        //we use the same set of weights and activations as the sample input in the golden model (python code) above.
		// weights = 144'h0008_0007_0006_0005_0004_0003_0002_0001_0000; 
        weights = 400'h0018_0017_0016_0015_0014_0013_0012_0011_0010_000F_000E_000D_000C_000B_000A_0009_0008_0007_0006_0005_0004_0003_0002_0001_0000; 
		for(i=0;i<255;i=i+1) begin
		activation = i;
		#clkp; 
		end
	end 
      always #(clkp/2) clk=~clk;
      
    integer k;
    initial begin
        for (k = 0; k < 100; k=k+1) @(posedge clk);
        $finish();
    end

endmodule
