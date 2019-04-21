module canPhyModel(
input clk,
input rxData,
output txData
);

reg [150:0] rxShiftReg=0;
integer clkCounter=0;

assign txData = (clkCounter == 106) ? 1'b0 : rxData;

always @(posedge clk)
begin
    rxShiftReg <= {rxShiftReg[149:0],rxData};
    clkCounter <= clkCounter + 1;
end

integer len,i;

initial
begin
    wait(clkCounter==13);
    @(posedge clk);
    $display("Identifier: %0b",rxShiftReg);  //received data might look different coz of bit stuffing
    @(posedge clk);
    $display("Req remote: %0b",rxShiftReg[0]);
    @(posedge clk);
    @(posedge clk);
    $display("ID extend: %0b",rxShiftReg[1:0]);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $display("Length: %0d",rxShiftReg[3:0]);
    len = rxShiftReg[3:0];
    for(i=0;i<len*8;i=i+1)
        @(posedge clk);
    $display("Data: %0x",rxShiftReg[63:0]);
end


endmodule