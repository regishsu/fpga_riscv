module spi_flash_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [23:0] addr,         // 欲讀取的 Flash 位址
    input  wire        rd_trigger,   // 觸發訊號 (高電位觸發)
    output reg  [7:0]  data_out,     // 讀取到的資料
    output wire        busy,         // 忙碌訊號 (1=忙碌)

    // SPI 物理接口
    output reg         flash_sclk,   // DCLK
    output reg         flash_cs_n,   // nCS
    output reg         flash_mosi,   // ASDO
    input  wire        flash_miso    // DATA0
);

    // 狀態機定義
//    localparam IDLE      = 3'd0;
//    localparam SEND_CMD  = 3'd1; // 發送 0x03 (Read Data)
//    localparam SEND_ADDR = 3'd2; // 發送 24-bit 地址
//    localparam READ_DATA = 3'd3; // 讀取 8-bit 數據
//    localparam DONE      = 3'd4;

		localparam IDLE      = 3'd0;
		localparam WAKEUP    = 3'd1; // 新增：發送 0xAB
		localparam SEND_CMD  = 3'd2; 
		localparam SEND_ADDR = 3'd3; 
		localparam READ_DATA = 3'd4;
		localparam DONE      = 3'd5;
		
    reg [2:0]  state;
    reg [5:0]  bit_cnt;   // 用於計算發送/接收了多少 bit
    reg [31:0] shift_reg; // 移位暫存器 (指令+地址)
    reg [7:0]  clk_cnt;   // 分頻計數器，用於產生 SPI SCLK

    // 產生 SPI 時鐘 (假設系統 50MHz, 分頻為 2, SCLK 約 12.5MHz 確保穩定)
    reg sclk_en;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 8'd0;
            flash_sclk <= 1'b0;
        end else if (sclk_en) begin
            if (clk_cnt == 8'd1) begin
                clk_cnt <= 8'd0;
                flash_sclk <= !flash_sclk; // 翻轉時鐘
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end else begin
            clk_cnt <= 8'd0;
            flash_sclk <= 1'b0;
        end
    end

    // 忙碌訊號定義：只要不在 IDLE，就是忙碌
    assign busy = (state != IDLE);

    // 狀態機主體
    always @(posedge clk or negedge rst_n) begin
			if (!rst_n) begin
				state      <= IDLE;
				flash_cs_n <= 1'b1;
				flash_mosi <= 1'b0;
				sclk_en    <= 1'b0;
				bit_cnt    <= 6'd0;
				data_out   <= 8'd0;
				shift_reg  <= 32'd0;
			end else begin
			case (state)
					IDLE: begin
                    flash_cs_n <= 1'b1;
                    if (rd_trigger) begin
                        state     <= SEND_CMD;
                        flash_cs_n <= 1'b0;
                        // 測試：發送 0x9F 指令，後面地址不重要
                        shift_reg <= {8'h9F, 24'h000000}; 
                        bit_cnt   <= 6'd0;
                    end
                end

                SEND_CMD: begin
                    sclk_en <= 1'b1;
                    if (clk_cnt == 8'd1 && flash_sclk == 1'b1) begin
                        flash_mosi <= shift_reg[31];
                        shift_reg  <= {shift_reg[30:0], 1'b0};
                        if (bit_cnt == 6'd7) begin // 8 bit 指令發完
                            bit_cnt <= 6'd0;
                            state   <= READ_DATA; // 直接跳到讀取，不要發地址
                        end else begin
                            bit_cnt <= bit_cnt + 1'b1;
                        end
                    end
                end
				 
				READ_DATA: begin
					  sclk_en <= 1'b1;
					  // 在 SCLK 的上升沿 (0 -> 1) 取樣 MISO
					  // 注意：這裡使用 clk_cnt == 0 且 flash_sclk == 1，代表剛跳到高電位的那一刻
					  if (clk_cnt == 8'd0 && flash_sclk == 1'b1) begin
							data_out <= {data_out[6:0], flash_miso};
					  end

					  // 在 SCLK 下降沿計數
					  if (clk_cnt == 8'd1 && flash_sclk == 1'b1) begin
							if (bit_cnt == 6'd7) begin
								 state <= DONE;
							end else begin
								 bit_cnt <= bit_cnt + 1'b1;
							end
					  end
				 end

				 DONE: begin
					  sclk_en    <= 1'b0;
					  flash_cs_n <= 1'b1;
					  state      <= IDLE;
				 end
				 
				 default: state <= IDLE;
			endcase
		end
	end

endmodule