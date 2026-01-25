`timescale 1ns/1ps

module tb;
    reg clk;
    reg reset_n;
    wire led1,led2,led3,led4;
	wire dclk,ncs,asdo,data0;
    //wire [3:0] dig;
	//wire [7:0] segm;
	wire ser_tx;
	wire ser_rx;

    // 實例化被測設計
    top uut (
        .clk(clk),
        .reset_n(reset_n),
		
        .led1(led1),
        .led2(led2),
        .led3(led3),
		.led4(led4),
		
		//.dig(dig),
		//.segm(segm),
		
		.ser_tx(ser_tx),
		.ser_rx(ser_rx),
		
		.dclk(dclk),
		.ncs(ncs),
		.asdo(asdo),
		.data0(data0)
    );

    initial begin
    	clk = 0;
        reset_n = 1;
        #10;
        reset_n = 0;
        #10;
        reset_n = 1;
  
        // 觀察 PC 或 LED 是否變化
        #100; 
        
        //$display("Simulation Ended. LEDs: %b%b%b", led1, led2, led3);
        $stop; // 停止模擬供用戶查看波形
    end
    // 產生時脈
    //initial clk = 0;
    always #10 clk = ~clk; // 50MHz
endmodule
