/*

 2026-01-23 add ALTPLL
 1-24 SDRAM-16bit Ok

*/

module top (
		input  clk,
		input  reset_n,
		// --- 新增 SDRAM 引腳 ---
		output        dram_clk,   // SDRAM 時鐘 (接 PLL 的 c1, -3ns 偏移)
		output        dram_cke,   // SDRAM Clock Enable
		output        dram_cs_n,  // SDRAM Chip Select
		output        dram_ras_n, // SDRAM Row Address Strobe
		output        dram_cas_n, // SDRAM Column Address Strobe
		output        dram_we_n,  // SDRAM Write Enable
		output [1:0]  dram_ba,    // SDRAM Bank Address (BA0, BA1)
		output [11:0] dram_addr,  // SDRAM Address Bus (A0 - A11)
		inout  [15:0] dram_dq,    // SDRAM Data Bus (DQ0 - DQ15)
		output [1:0]  dram_dqm,   // SDRAM Data Mask (LDQM, UDQM)
		// --- 新增 EPCS / SPI Flash 引腳 ---
		output wire dclk,        // 連接到 EPCS 的 DCLK
		output wire ncs,         // 連接到 EPCS 的 nCSO (Data chip select)
		output wire asdo,        // 連接到 EPCS 的 ASDO (Address/Data serial output)
		input  wire data0,       // 連接到 EPCS 的 DATA0 (Data input)
		
		// 原有的 LED 與 七段顯示器
		output wire led1,
		output wire led2,
		output wire led3,
		output wire led4,
		output reg [3:0] dig,
		output reg [7:0] segm,
		
		//UART port
		output wire ser_tx,
		input wire ser_rx
);

	parameter [0:0] BARREL_SHIFTER = 1;
	parameter [0:0] ENABLE_MUL = 0;
	parameter [0:0] ENABLE_DIV = 0;
	parameter [0:0] ENABLE_FAST_MUL = 0;
	parameter [0:0] ENABLE_COMPRESSED = 1;
	parameter [0:0] ENABLE_COUNTERS = 1;
	parameter [0:0] ENABLE_IRQ_QREGS = 0;
	parameter [0:0] ENABLE_REGS_DUALPORT = 0;

	parameter integer MEM_WORDS = 512;
	parameter [31:0] STACKADDR = (4*MEM_WORDS);       // end of memory
	parameter [31:0] PROGADDR_RESET = 32'h 0000_0000; // 1 MB into flash


		// 定義 4 個顯示器的暫存器
		reg [7:0] seg0, seg1, seg2, seg3;
		
		// --- PicoRV32 內部訊號 ---
		wire [31:0] mem_addr;
		wire [31:0] mem_wdata;
		wire [3:0]  mem_wstrb;
		wire [31:0] mem_rdata;
		wire [31:0] sdram_rdata;
		wire [31:0] ram_rdata;
		
		wire        trap;
		wire        mem_valid;
		wire        mem_instr;
		wire        mem_ready;
		reg 			ram_ready;
		wire 			led_ready;
		wire			sdram_ready;
		wire			uart_ready;
		
		
		// --- 位址解碼 (Address Decoding) ---
		// RAM 範圍: 0x0000_0000 ~ 0x0000_1FFF (8KB)
		// LED 範圍: 0x0100_0000
		// FLASH 範圍: 0x0200_0000
		// UART 範圍: 0x0200_0004 除頻register
		// UART 範圍: 0x0200_0008 資料register
		
		//wire spimemio_cfgreg_sel = mem_valid && (mem_addr == 32'h 0200_0000);
		//wire [31:0] spimemio_cfgreg_do;
		
		//UART address setting
		wire        simpleuart_reg_div_sel = mem_valid && (mem_addr == 32'h 0200_0004);
		wire [31:0] simpleuart_reg_div_do;
		wire        simpleuart_reg_dat_sel = mem_valid && (mem_addr == 32'h 0200_0008);
		wire [31:0] simpleuart_reg_dat_do;
		wire        simpleuart_reg_dat_wait;
		
		//boot RAM & LED address setting
		wire is_ram = mem_valid && (mem_addr[31:24] == PROGADDR_RESET);
		wire is_led = mem_valid && (mem_addr[31:24] == 8'h01);
		wire is_sdram = mem_valid && (mem_addr[31:24] == 8'h04);  //0400_0000
		// SDRAM固定輸出訊號
		//assign dram_cke = 1'b1;        // 通常固定為高電位
		//assign dram_cs_n = 1'b0;       // 通常固定選中 (Low Active)
		assign dram_clk = clk_sdram;   // 接 PLL c1 (-3ns), 外部 SDRAM 晶片的時鐘
										
		assign mem_ready = sdram_ready || 
									ram_ready || led_ready || simpleuart_reg_div_sel || uart_ready;
	
		assign mem_rdata = ram_ready ? ram_rdata :
									sdram_ready ? sdram_rdata :
									simpleuart_reg_div_sel ? simpleuart_reg_div_do :
									//simpleuart_reg_dat_sel ? simpleuart_reg_dat_do : 32'h 0000_0000;
									uart_ready ? simpleuart_reg_dat_do : 32'h 0000_0000;
	
		//各模組的 Ready 訊號
		always @(posedge clk_sys) ram_ready <= (mem_valid && is_ram) && !ram_ready;
		assign uart_ready = simpleuart_reg_dat_sel && !simpleuart_reg_dat_wait;
		assign led_ready = is_led;
		//assign sdram_ready = (|mem_wstrb) ? !sdram_busy : sdram_rd_ready;
		assign sdram_ready = (mem_valid && is_sdram) && !sdram_busy;
		
		//assign led1 = !spimem_ready; // 熄滅代表已完成應答
		assign led2 = !uart_ready; // 亮代表觸發中
		assign led3 = !sdram_ready;            
		assign led4 = !trap;
		
		//assign led2 = !(mem_valid && spi_sel); // 觀察 CPU 是否有在嘗試存取 SPI 區域
		
		
		/* ==========================================================
		
		  功能模組實例化
		
		  ========================================================== */
		
		// --- PLL 實例化 ---
		wire clk_sys;    // 50MHz, 0 deg (內部邏輯用)
		wire clk_sdram;  // 50MHz, -3ns (外部晶片用)
		wire pll_locked; // 指示 PLL 是否穩定
		
		my_pll pll_inst (
			 .inclk0 (clk),        // 接板子上的 50MHz 晶振
			 .c0     (clk_sys),    // 取代原本 top.v 裡所有的 clk
			 .c1     (clk_sdram),  // 直接接出到 fpga 引腳 dram_clk
			 .locked (pll_locked)  // 可以接 LED 觀察
		);
		

		// --- 修正內部邏輯 ---
		// 所有的 always @(posedge clk) 都要改成 always @(posedge clk_sys)
		// 包含 CPU, RAM, SPI, UART 全部的 clk 都要換成 clk_sys

		
		//硬體LED閃爍燈, debug
		//reg [24:0] cnt;
		//always @(posedge clk_sys) cnt <= cnt + 1;
		//assign led4 = cnt[24]; // 應該會每秒閃爍一次	
		
		// --- 七段顯示器掃描控制 ---
		reg [15:0] scan_cnt; // 掃描頻率計數器
		reg [1:0]  scan_sel; // 目前選擇哪一個顯示器 (0-3)
		always @(posedge clk_sys) begin
		  if (!reset_n) begin
				// all of segments are off
				seg0 <= 8'hff; seg1 <= 8'hff; seg2 <= 8'hff; seg3 <= 8'hff;
		  end else if (mem_ready && is_led) begin
				// mem_wstrb[0] 控制第一個 Byte (seg0)
				if (mem_wstrb[0]) seg0 <= mem_wdata[7:0];
		  
				// mem_wstrb[1] 控制第二個 Byte (seg1)
				if (mem_wstrb[1]) seg1 <= mem_wdata[15:8];
		  
				// mem_wstrb[2] 控制第三個 Byte (seg2)
				if (mem_wstrb[2]) seg2 <= mem_wdata[23:16];
		  
				// mem_wstrb[3] 控制第四個 Byte (seg3)
				if (mem_wstrb[3]) seg3 <= mem_wdata[31:24];
		  end
		end
		
		always @(posedge clk_sys) begin
			scan_cnt <= scan_cnt + 1'b1;
			// 假設 clk 為 50MHz，scan_cnt[15] 大約每 1.3ms 翻轉一次
			if (scan_cnt == 16'hFFFF) begin
				  scan_sel <= scan_sel + 1'b1;
			end
		end
		
		// --- 掃描邏輯 (Multiplexing) ---
		always @(*) begin
			case (scan_sel)
			  2'b00: begin
					dig  = 4'b1110; // 點亮第 1 顆 (低位元有效)
					segm = seg0;
			  end
			  2'b01: begin
					dig  = 4'b1101; // 點亮第 2 顆
					segm = seg1;
			  end
			  2'b10: begin
					dig  = 4'b1011; // 點亮第 3 顆
					segm = seg2;
			  end
			  2'b11: begin
					dig  = 4'b0111; // 點亮第 4 顆
					segm = seg3;
			  end
			endcase
		end
		
		// 實例化 Intel RAM IP (altsyncram) ---
		// 請確認你的 RAM IP 腳本中，address 寬度是 11 bits (對應 2048 words)
		my_ram_ip ram_inst (
			.address (mem_addr[12:2]), // Word 對齊
			.clock   (clk_sys       ),
			.data    (mem_wdata     ),
			.wren    (is_ram && (|mem_wstrb)),
			.q       (ram_rdata     )
		);
		
		// CPU 延遲reset計數器，確保 reset 至少維持 16 個週期
		reg [3:0] reset_cnt = 0;
		reg cpu_resetn = 0; // 給 CPU 用的重置訊號 (Low Active)

		always @(posedge clk or negedge reset_n) begin
			 if (!reset_n) begin
				  reset_cnt <= 0;
				  cpu_resetn <= 0;
			 end else begin
				  if (reset_cnt < 4'd15) begin
						reset_cnt <= reset_cnt + 1'b1;
						cpu_resetn <= 0;
				  end else begin
						cpu_resetn <= 1; // 15 個週期後釋放重置
				  end
			 end
		end

    // 實例化 PicoRV32 ---
	 // reserve 			
	 //.PROGADDR_IRQ(PROGADDR_IRQ),
	 //.ENABLE_IRQ(1),
	 //.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS) 
    picorv32 #(
			.STACKADDR(STACKADDR),
			.PROGADDR_RESET(PROGADDR_RESET),  // 從這個位址開始跑
			.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
			.BARREL_SHIFTER(BARREL_SHIFTER),
			.COMPRESSED_ISA(ENABLE_COMPRESSED),
			.ENABLE_COUNTERS(ENABLE_COUNTERS),
			.ENABLE_MUL(ENABLE_MUL),
			.ENABLE_DIV(ENABLE_DIV),
			.ENABLE_FAST_MUL(ENABLE_FAST_MUL)
    ) cpu (
        .clk         (clk_sys    ),
        .resetn      (cpu_resetn && pll_locked),
        .trap        (trap       ),
        .mem_valid   (mem_valid  ),
        .mem_instr   (mem_instr  ),
        .mem_ready   (mem_ready  ),
        .mem_addr    (mem_addr   ),
        .mem_wdata   (mem_wdata  ),
        .mem_wstrb   (mem_wstrb  ),
        .mem_rdata   (mem_rdata  )
    );

		
		//實例化 uart 
		simpleuart simpleuart (
		.clk         (clk_sys   ),
		.resetn      (reset_n   ),
		.ser_tx      (ser_tx    ),
		.ser_rx      (ser_rx    ),
		.reg_div_we  (simpleuart_reg_div_sel ? mem_wstrb : 4'b0000),
		.reg_div_di  (mem_wdata),
		.reg_div_do  (simpleuart_reg_div_do),
		.reg_dat_we  (simpleuart_reg_dat_sel ? mem_wstrb[0] : 1'b0),
		.reg_dat_re  (simpleuart_reg_dat_sel && !mem_wstrb),
		.reg_dat_di  (mem_wdata),
		.reg_dat_do  (simpleuart_reg_dat_do),
		.reg_dat_wait(simpleuart_reg_dat_wait)
	);
	
	// --- 實例SDRAM控制器 ---
// 內部中間訊號
    wire [15:0] sdram_data_out; // 晶片是 16-bit
    wire sdram_busy;
    wire sdram_rd_ready;

    // --- 實例化 GitHub 版 SDRAM 控制器 ---
    sdram_controller #(
        .ROW_WIDTH(12),          // HY57V641620 規格
        .COL_WIDTH(8),           // HY57V641620 規格
        .BANK_WIDTH(2),
		  .CLK_FREQUENCY(50),      // 你的 PLL 輸出頻率
		  .REFRESH_TIME(65),
		  .REFRESH_COUNT(4096)
    ) sdram_inst (
        /* HOST INTERFACE */
        // 位址處理：mem_addr 是字節位址，SDRAM 是 16-bit 寬，所以右移 1 位 (addr[0] 消失)
        .wr_addr   (mem_addr[22:1]), 
        .wr_data   (mem_wdata[15:0]),
        .wr_enable (is_sdram && mem_valid && (|mem_wstrb)),

        .rd_addr   (mem_addr[22:1]),
        .rd_data   (sdram_data_out),
        .rd_ready  (sdram_rd_ready),
        .rd_enable (is_sdram && mem_valid && !(|mem_wstrb)),

        .busy      (sdram_busy),
        .rst_n     (reset_n && pll_locked),
        .clk       (clk_sys),

        /* SDRAM SIDE - 直接連接到頂層引腳 */
        .addr          (dram_addr),
        .bank_addr     (dram_ba),
        .data          (dram_dq),
        .clock_enable  (dram_cke),
        .cs_n          (dram_cs_n),
        .ras_n         (dram_ras_n),
        .cas_n         (dram_cas_n),
        .we_n          (dram_we_n),
        .data_mask_low (dram_dqm[0]), // LDQM
        .data_mask_high(dram_dqm[1])  // UDQM
    );

    // --- 匯流排訊號橋接 ---

    // 1. 處理 Data Out: 將 16-bit 擴展回 32-bit 給 PicoRV32
    assign sdram_rdata = {16'h0000, sdram_data_out};
							 
endmodule