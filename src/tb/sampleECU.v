module sampleECU #(parameter xcord=0, ycord=0,data_width=129)(
input clk,
input rst,
output reg [130:0] o_data,
output reg o_valid,
input [130:0] i_data,
input i_valid,
input i_ready
);

initial
begin
    wait(!rst)
    if(xcord==1 && ycord==0)
    begin
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        o_valid = 1;
        o_data[0] = 1'b0;
        o_data[1] = 1'b0;
        o_data[129:2] = 128'hcb0000000eafac43_800000004b200000;
        o_data[130] = 1'b1;
        @(posedge clk);
        o_valid = 0;
    end
end

endmodule