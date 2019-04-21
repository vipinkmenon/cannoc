`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2018 10:15:28 PM
// Design Name: 
// Module Name: canNoc
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module canNoc #(parameter X=2,Y=2,data_width=129, x_size=1, y_size=1,total_width=(x_size+y_size+data_width))
(
input   wire    clk,
input   wire    rst,
//CAN External interface
input   wire    can_clk,   
input   wire    can_phy_rx,
output  wire    can_phy_tx,
//To PEs
input wire [(X*Y-1)-1:0] r_valid_pe,
input wire [(total_width*(X*Y-1))-1:0] r_data_pe,
output wire [(X*Y-1)-1:0] r_ready_pe,
output wire [(X*Y-1)-1:0] w_valid_pe,
output wire [(total_width*(X*Y-1))-1:0] w_data_pe
);
 


wire [total_width-1:0] canToSwitchData;
wire canToSwitchDataValid;
wire canToSwitchDataReady; 
wire [total_width-1:0] switchToCanData;
wire switchToCanDataValid;

    
interfacePe #(.X(2),.Y(2),.data_width(129), .x_size(1), .y_size(1)) interfacePe
( 
    .clk(clk),
    .rst(rst),
    .i_data(switchToCanData),
    .i_valid(switchToCanDataValid),
    .o_data(canToSwitchData),
    .o_valid(canToSwitchDataValid),
    .i_ready(canToSwitchDataReady),
    .can_clk(can_clk),   
    .can_phy_rx(can_phy_rx),
    .can_phy_tx(can_phy_tx)
);    
    
    
    
openNocTop #(.X(2),.Y(2),.data_width(129), .x_size(1), .y_size(1)) ON
    (
    .clk(clk),
    .rstn(!rst),
    .r_valid_pe({r_valid_pe,canToSwitchDataValid}),
    .r_data_pe({r_data_pe,canToSwitchData}),
    .r_ready_pe({r_ready_pe,canToSwitchDataReady}),
    .w_valid_pe({w_valid_pe,switchToCanDataValid}),
    .w_data_pe({w_data_pe,switchToCanData})
);
  
    
endmodule
