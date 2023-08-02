`timescale 1ns / 1ps

`define INTERPOLATE 1  // interpolation

module tanh_lut #(
    parameter AW = 10,  // AW(address width) will be based on the size of the ROM we can afford in our design.
                        // in the best case AW = N;
    parameter DW = 16,  // data width
    parameter N = 16,
    parameter Q = 12
)(
    input clk,
    input rst,
    input [N-1:0] phase,  // use N because of interpolation
    output [DW-1:0] tanh
);
    
    reg [AW-1:0] addra_reg;
    wire [DW-1:0] tanha;
    wire [DW-1:0] tanhb;
    wire ovr1,ovr2;
    `ifdef INTERPOLATE
        reg [AW-1:0] addrb_reg;
    `endif

    (* ram_style = "block" *) reg [DW-1:0] mem [(1<<AW)-1:0];  // ram_style can be 'block' or 'distributed' based on the utilization and other requirements in the project
    
    initial begin
        // $readmemb("tanh_data.mem", mem);  // loading RAM
        $readmemb("D:/_2022/cnn_hardware_acclerator_for_fpga/cnn_accelerator_on_fpga/src/tanh_data.mem", mem);  // loading RAM
    end

    always @(posedge clk) begin
        addra_reg <= phase[AW-1:0];
        `ifdef INTERPOLATE
            addrb_reg <= phase[AW-1:0] + 1'b1;
        `endif
    end

    `ifdef INTERPOLATE
        assign tanhb = mem[addrb_reg];
    `endif
    assign tanha = mem[addra_reg];


    wire [15:0] frac, one_minus_frac;
    wire [15:0] p1, p2;
    wire [15:0] one;
    wire [DW-1:0] tanh_temp;

    // assign frac = {'d0, phase[N-AW-'d2-1:0]};  // rest of the LSBs that were not accounted for owing to the limited ROM size
    assign frac = {12'd0, phase[N-AW-'d2-1:0]};  // 注意这里要改
    assign one = 16'b0001000000000000;  // 'd1 in (N,Q) = (3,12) format
    assign one_minus_frac = one - frac;
    // qmult is the fixed point multiplier module, visit the fixed point arithmetic article further in the series to learn of its exact operation
    qmult #(N,Q) mul1 (clk,rst,tanha,frac,p1,ovr1);  // calculates x*f(Ai)
    qmult #(N,Q) mul2 (clk,rst,tanhb,one_minus_frac,p2,ovr2);  // calculates (1-x)*f(Ai+1)
    assign tanh_temp = p1 + p2;    // linear interpolation formula: x*Pi + (1-x)*Pi+1

    // now, if the phase input is above 3 or below -3 then we just output 1, otherwise we output the calculated value
    // we also check for the sign, if the phase is negative, we return 2's complemented version of the calculated value
    assign tanh = (phase [N-1]) ? (phase[N-2] ? (16'b1111000000000000) : (~tanh_temp + 1'b1)) :(phase[N-2] ? (16'b0001000000000000):(tanh_temp));
    

endmodule
