`timescale 1ns/1ps

module ecuMesh  #(parameter X=2,Y=2,data_width=129, x_size=1, y_size=1,total_width = (x_size+y_size+data_width))
(
input  wire clk,
input  wire rst,
//PE interfaces
output wire [(X*Y-1)-1:0]               r_valid_pe,
output wire [(total_width*(X*Y-1))-1:0] r_data_pe,
input  wire [(X*Y-1)-1:0]               r_ready_pe,
input  wire [(X*Y-1)-1:0]               w_valid_pe,
input  wire [(total_width*(X*Y-1))-1:0] w_data_pe
);

generate
	genvar x, y; 
	for (x=0;x<X;x=x+1) begin:xs
		for (y=0; y<Y; y=y+1) begin:ys
            if(x !=0 || y!= 0)
            begin:inst
                sampleECU #(.xcord(x), .ycord(y)) ECU (
                    .clk(clk),
                    .rst(rst),
                    .i_data(w_data_pe[(total_width*x)+(total_width*X*y)-total_width+:total_width]),
                    .i_valid(w_valid_pe[x+X*y-1]),
                    .o_data(r_data_pe[(total_width*x)+(total_width*X*y)-total_width+:total_width]),
                    .o_valid(r_valid_pe[x+X*y-1]),
                    .i_ready(r_ready_pe[x+X*y-1])
                    );
            end
		end
	end			
endgenerate 

endmodule