module interfacePe #(parameter X=2,Y=2,data_width=129, x_size=1, y_size=1,total_width=(x_size+y_size+ data_width)) (
//From NoC
input   wire clk,
input   wire rst,
input   wire [total_width-1:0] i_data,
input   wire i_valid,
output  reg  [total_width-1:0] o_data,
output  reg  o_valid,
input   wire i_ready,
//CAN External interface
input   wire can_clk,   
input   wire can_phy_rx,
output  wire can_phy_tx
);

wire TxFifoEmpty;
reg  s_axi_awvalid;
wire s_axi_awready;
reg  s_axi_wvalid;
reg  txFifoRdEn;
reg [7 : 0] s_axi_awaddr;
reg [7 : 0] s_axi_araddr;
reg  s_axi_bready;
wire s_axi_bvalid;
wire s_axi_wready;
wire s_axi_arready;
reg [31:0] canSendData;
reg [31:0] canRxData;
wire [31:0] s_axi_rdata;
reg [2:0] confAddress;
reg [3:0] commandIndex;
reg [31:0] confData[5:0];
reg [31:0] confAddr[5:0];
reg [31:0] txFifoSendData [3:0];
reg [31:0] rxFifoWrData [3:0];
wire [128:0] txFifoData;
wire  [128:0] rxFifoData;
reg  [127:0] broadCastData;
reg [2:0] DataIndex;
reg  s_axi_arvalid;
wire  s_axi_rvalid;
wire  RxFifoEmpty;
reg rxFifoWrEn;
reg probeSend;
reg sendDone;
reg [x_size+y_size-1: 0] destAddress;
reg rxFifoRdEn;
wire [128:0] rxFifoReceiveData; 
reg BCState;

assign rxFifoData = {1'b0,rxFifoWrData[3],rxFifoWrData[2],rxFifoWrData[1],rxFifoWrData[0]};

localparam numPe = X*Y;

initial
begin
    confData[0] = 'h0;   //Data to Mode select register No loop back and sleep
    confData[1] = 'h1;   //To Baudrate prescale register
    confData[2] = 'hb8;  //To Bit timing register 
    confData[3] = 'h2;   //CAN Enable to software reset register
end


initial
begin
    confAddr[0] = 'h4;
    confAddr[1] = 'h8;
    confAddr[2] = 'hc;
    confAddr[3] = 'h0;
end

reg [3:0] sendState;
reg [3:0] prevState;
reg [3:0] recvState;

localparam   
            CONF          = 'd0,
            IDLE          = 'd1,
            SendData      = 'd2,
            SendAxiData   = 'd3,
            CheckTxStatus = 'd4,
            CheckInterrupt   = 'd5,
            ReceiveData = 'd6,
            CheckRxData = 'd7,
            CheckRxStatus = 'd8,
            GetData = 'd9,
            ClrRxInterrupt = 'd10;
            
localparam sendIDLE = 'd0,
           BroadCast = 'd1;
           

always @(posedge clk)
begin
    if(rst)
    begin
        sendState <= CONF;
        s_axi_awvalid <= 1'b0;
        s_axi_wvalid <= 1'b0;
        txFifoRdEn <= 1'b0;
        commandIndex <= 0;
        rxFifoRdEn <= 0;
        s_axi_bready <= 1'b0;
        s_axi_arvalid <= 1'b0;
        rxFifoWrEn <= 1'b0;
    end
    else
    begin
        case(sendState)
            /*Configure the CAN internal control registers with baudrate, bit timing etc.*/
            CONF:begin
                if(commandIndex == 4)
                begin
                    sendState <= IDLE;
                end
                else
                begin
                    s_axi_awvalid <= 1'b1;
                    s_axi_wvalid <= 1'b1;
                    s_axi_bready <= 1'b1;
                    s_axi_awaddr <= confAddr[commandIndex];
                    canSendData <= confData[commandIndex];
                    commandIndex <= commandIndex + 1;
                    sendState <= SendAxiData;
                    prevState <= CONF;
                end
            end
            SendAxiData:begin
                if(s_axi_awready)
                    s_axi_awvalid <= 1'b0;
                if(s_axi_wready)
                    s_axi_wvalid <= 1'b0;
                if(s_axi_bvalid)
                begin
                    s_axi_bready <= 1'b0;
                    sendState <= prevState;
                end
            end
            IDLE:begin
                rxFifoWrEn <= 1'b0;
                /*Check whether any data is received in the transmit FIFO*/
                if(!TxFifoEmpty)
                begin
                    //Send the data to CAN controller
                    s_axi_awaddr <= 'h2C;
                    txFifoSendData[0] <= txFifoData[31:0];
                    txFifoSendData[1] <= txFifoData[63:32];
                    txFifoSendData[2] <= txFifoData[95:64];
                    txFifoSendData[3] <= txFifoData[127:96];
                    DataIndex <= 0;
                    txFifoRdEn    <= 1'b1; 
                    sendState     <= SendData;
                    /*If broad cast bit is set, data has to be sent externally as well as to the NoC*/
                    if(txFifoData[128] == 1'b1)
                    begin
                        //Put the data to Rx FIFO for NoC broadcast
                        rxFifoWrEn <= 1'b1;
                        rxFifoWrData[0] <= txFifoData[31:0];
                        rxFifoWrData[1] <= txFifoData[63:32];
                        rxFifoWrData[2] <= txFifoData[95:64];
                        rxFifoWrData[3] <= txFifoData[127:96];                        
                    end
                end
                else
                begin
                        sendState <= CheckRxData;
                end
            end
            SendData:begin
                rxFifoWrEn    <= 1'b0;
                txFifoRdEn    <= 1'b0;
                if(DataIndex == 'h4)
                begin
                    sendState <= CheckTxStatus;
                end
                else
                begin
                    sendState <= SendAxiData;
                    s_axi_awvalid <= 1'b1;
                    s_axi_wvalid  <= 1'b1;
                    s_axi_bready  <= 1'b1;
                    canSendData   <= txFifoSendData[DataIndex];
                    prevState     <= SendData;
                    DataIndex <= DataIndex+1'b1;
                    s_axi_awaddr <= s_axi_awaddr + 4;
                end
            end
            CheckTxStatus:begin
                s_axi_arvalid <= 1'b1;
                s_axi_araddr <= 'h1C;
                prevState <= CheckInterrupt;
                sendState <= ReceiveData;
            end
            CheckInterrupt:begin
                if(canRxData[1])
                begin
                    s_axi_awaddr  <= 'h24;
                    s_axi_awvalid <= 1'b1;
                    s_axi_wvalid  <= 1'b1;
                    s_axi_bready  <= 1'b1;
                    canSendData   <= 'h02;
                    sendState <= SendAxiData;
                    prevState <= CheckRxData;
                end
                else
                begin
                    sendState <= CheckTxStatus;
                end
            end
            ReceiveData:begin
                if(s_axi_arready)
                    s_axi_arvalid <= 1'b0;
                if(s_axi_rvalid)
                begin
                    canRxData <= s_axi_rdata;
                    sendState <= prevState;
                end
            end
            
            CheckRxData:begin
                s_axi_arvalid <= 1'b1;
                s_axi_araddr <= 'h1C;
                prevState <= CheckRxStatus;
                sendState <= ReceiveData;
            end
            
            CheckRxStatus:begin
                if(canRxData[4])
                begin
                    s_axi_araddr <= 'h50;
                    s_axi_arvalid <= 1'b1;
                    prevState <= GetData;
                    sendState <= ReceiveData;
                    DataIndex <= 0;
                end
                else
                    sendState <= IDLE;
            end
            
            GetData:begin
                if(DataIndex == 4)
                begin
                    sendState <= ClrRxInterrupt;
                    rxFifoWrEn <= 1'b1;
                end
                else
                begin
                    rxFifoWrData[DataIndex] <= s_axi_rdata;
                    DataIndex <= DataIndex + 1;
                    s_axi_araddr <= s_axi_araddr + 4;
                    s_axi_arvalid <= 1'b1;
                    prevState <= GetData;
                    sendState <= ReceiveData;
                end
            end
            ClrRxInterrupt:begin
                rxFifoWrEn    <= 1'b0;
                s_axi_awaddr  <= 'h24;
                s_axi_awvalid <= 1'b1;
                s_axi_wvalid  <= 1'b1;
                s_axi_bready  <= 1'b1;
                canSendData   <= 'h90;
                sendState <= SendAxiData;
                prevState <= IDLE;
            end
        endcase
    end
end


always @(posedge clk)
begin
    if(rst)
    begin
        destAddress <= 1'b1;
        rxFifoRdEn <= 1'b0;
        BCState <= sendIDLE;
        o_valid <= 1'b0;
    end
    else
    begin
        case(BCState)
            sendIDLE:begin
                if(!RxFifoEmpty)
                begin
                    o_data <= {rxFifoReceiveData,destAddress};
                    destAddress <= destAddress+1;
                    o_valid <= 1'b1;
                    rxFifoRdEn <= 1'b1;
                    BCState <= BroadCast;
                end
             end
             BroadCast:begin
                rxFifoRdEn <= 1'b0;
                if(i_ready)
                begin
                    if(destAddress == 0)
                    begin
                        BCState <= sendIDLE;
                        o_valid <= 1'b0;
                        destAddress <= 1;
                    end
                    else
                    begin
                        o_data <= {rxFifoReceiveData,destAddress};
                        destAddress <= destAddress+1;
                    end
                end
             end
        endcase
    end
end        

pktFifo TxPktFifo (
  .clk(clk),      
  .srst(rst),    
  .din(i_data[x_size+y_size+:129]),   
  .wr_en(i_valid),
  .rd_en(txFifoRdEn), 
  .dout(txFifoData),  
  .full(),    
  .empty(TxFifoEmpty)  
);

pktFifo RxPktFifo (
  .clk(clk),      
  .srst(rst),    
  .din(rxFifoData),   
  .wr_en(rxFifoWrEn),
  .rd_en(rxFifoRdEn), 
  .dout(rxFifoReceiveData),  
  .full(rxFifoFull),    
  .empty(RxFifoEmpty)  
);


can_0 CANMac (
  .can_clk(can_clk),                    // input wire can_clk
  .can_phy_rx(can_phy_rx),              // input wire can_phy_rx
  .can_phy_tx(can_phy_tx),              // output wire can_phy_tx
  .ip2bus_intrevent(ip2bus_intrevent),  // output wire ip2bus_intrevent
  .s_axi_aclk(clk),              // input wire s_axi_aclk
  .s_axi_aresetn(!rst),        // input wire s_axi_aresetn
  .s_axi_awaddr(s_axi_awaddr),          // input wire [7 : 0] s_axi_awaddr
  .s_axi_awvalid(s_axi_awvalid),        // input wire s_axi_awvalid
  .s_axi_awready(s_axi_awready),        // output wire s_axi_awready
  .s_axi_wdata(canSendData),            // input wire [31 : 0] s_axi_wdata
  .s_axi_wstrb(4'hF),                   // input wire [3 : 0] s_axi_wstrb
  .s_axi_wvalid(s_axi_wvalid),          // input wire s_axi_wvalid
  .s_axi_wready(s_axi_wready),          // output wire s_axi_wready
  .s_axi_bresp(),                       // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(s_axi_bvalid),          // output wire s_axi_bvalid
  .s_axi_bready(s_axi_bready),          // input wire s_axi_bready
  .s_axi_araddr(s_axi_araddr),          // input wire [7 : 0] s_axi_araddr
  .s_axi_arvalid(s_axi_arvalid),        // input wire s_axi_arvalid
  .s_axi_arready(s_axi_arready),        // output wire s_axi_arready
  .s_axi_rdata(s_axi_rdata),            // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp(),                       // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid(s_axi_rvalid),          // output wire s_axi_rvalid
  .s_axi_rready(!rxFifoFull)            // input wire s_axi_rready
);


endmodule