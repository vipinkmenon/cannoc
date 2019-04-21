`timescale 1ns/1ps

`define canclkdelay 10
`define phyclkdelay (28*`canclkdelay)


`define X 2
`define Y 2
`define x_size $clog2(`X)
`define y_size $clog2(`Y)
`define data_width 129
`define total_width (`x_size+`y_size+`data_width)


module tb();

reg clk;
reg canClk;
reg reset;
reg valid;
reg [128:0] data;

reg canphyClk;

wire phyTxData,phyRxData;

wire [(`X*`Y-1)-1:0] r_valid_pe;
wire [(`total_width*(`X*`Y-1))-1:0] r_data_pe;
wire [(`X*`Y)-1:0] r_ready_pe;
wire [(`X*`Y)-1:0] w_valid_pe;
wire [(`total_width*(`X*`Y-1))-1:0] w_data_pe;

initial
begin
    canphyClk = 0;
    wait(!phyRxData);
    forever
    begin
        canphyClk = ~canphyClk;
        #`phyclkdelay;
    end
end

initial
begin
    clk = 0;
    forever 
    begin
        clk = ~clk;
        #4;
    end
end

initial
begin
    canClk = 0;
    forever 
    begin
        canClk = ~canClk;
        #`canclkdelay;
    end
end

initial
begin
    reset = 1;
    #100;
    reset = 0;
end

canNoc CN(
    .clk(clk),
    .rst(reset),
    //CAN External interface
    .can_clk(canClk),   
    .can_phy_rx(phyTxData),
    .can_phy_tx(phyRxData),
    //To PEs
    .r_valid_pe(r_valid_pe),
    .r_data_pe(r_data_pe),
    .r_ready_pe(r_ready_pe),
    .w_valid_pe(w_valid_pe),
    .w_data_pe(w_data_pe)
);

ecuMesh #(.X(`X),.Y(`Y),.data_width(`data_width), .x_size(`x_size),.y_size(`y_size)) 
ecuMesh(
.clk(clk),
.rst(reset),
//PE interfaces
.r_valid_pe(r_valid_pe),
.r_data_pe(r_data_pe),
.r_ready_pe(r_ready_pe),
.w_valid_pe(w_valid_pe),
.w_data_pe(w_data_pe)
);


canPhyModel phy(
.clk(canphyClk),
.rxData(phyRxData),
.txData(phyTxData)
);


endmodule