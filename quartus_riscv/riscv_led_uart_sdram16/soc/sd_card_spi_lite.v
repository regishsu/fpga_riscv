module sd_card_spi_lite (
    input  wire        clk,        // 系統 50MHz
    input  wire        rst_n,
    // SD 實體引腳
    output reg         sd_cs,
    output reg         sd_sclk,
    output reg         sd_mosi,
    input  wire        sd_miso,
    // 介面
    input  wire [31:0] sector_addr,
    input  wire        rd_trigger,
    output reg [7:0]   out_data,
    output reg         out_valid,
    output reg         busy
);

    // 狀態機
    localparam S_IDLE       = 0,
               S_INIT_DUMMY = 1,
               S_SEND_CMD0  = 2,
               S_WAIT_R1    = 3,
               S_SEND_CMD17 = 4,
               S_WAIT_FE    = 5,
               S_READ_DATA  = 6,
               S_DONE       = 7;

    reg [3:0]  state;
    reg [7:0]  cmd_buffer [0:5];
    reg [3:0]  byte_cnt;
    reg [2:0]  bit_cnt;
    reg [15:0] clk_div;
    reg [9:0]  data_cnt;
    
    // SPI 時鐘產生器 (初始化建議 400kHz)
    always @(posedge clk) clk_div <= clk_div + 1'b1;
    wire spi_clk = clk_div[6]; // 50MHz / 128 = ~390kHz

    // 指令內容: CMD17 (讀取扇區)
    // 格式: 01 + Index(6bits) + Addr(32bits) + CRC(7bits) + 1
    always @(*) begin
        cmd_buffer[0] = 8'h51; // CMD17
        cmd_buffer[1] = sector_addr[31:24];
        cmd_buffer[2] = sector_addr[23:16];
        cmd_buffer[3] = sector_addr[15:8];
        cmd_buffer[4] = sector_addr[7:0];
        cmd_buffer[5] = 8'hFF; // SPI 模式下大部份 CMD 的 CRC 不重要，除了 CMD0
    end

    always @(posedge spi_clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            sd_cs <= 1;
            sd_mosi <= 1;
            busy <= 0;
            out_valid <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (rd_trigger) begin
                        state <= S_SEND_CMD17;
                        busy <= 1;
                        byte_cnt <= 0;
                        bit_cnt <= 7;
                        sd_cs <= 0;
                    end
                end

                S_SEND_CMD17: begin
                    sd_mosi <= cmd_buffer[byte_cnt][bit_cnt];
                    if (bit_cnt == 0) begin
                        bit_cnt <= 7;
                        if (byte_cnt == 5) state <= S_WAIT_R1;
                        else byte_cnt <= byte_cnt + 1;
                    end else bit_cnt <= bit_cnt - 1;
                end

                S_WAIT_R1: begin
                    sd_mosi <= 1; // 保持高電位等待回應
                    if (sd_miso == 0) begin // 收到 R1 回應 (0x00 代表 OK)
                        state <= S_WAIT_FE;
                    end
                end

                S_WAIT_FE: begin
                    if (sd_miso == 0) begin // 等待數據起始令牌 0xFE
                        state <= S_READ_DATA;
                        data_cnt <= 0;
                        bit_cnt <= 7;
                    end
                end

                S_READ_DATA: begin
                    out_data[bit_cnt] <= sd_miso;
                    if (bit_cnt == 0) begin
                        out_valid <= 1;
                        bit_cnt <= 7;
                        if (data_cnt == 511) state <= S_DONE;
                        else data_cnt <= data_cnt + 1;
                    end else out_valid <= 0;
                end

                S_DONE: begin
                    out_valid <= 0;
                    sd_cs <= 1;
                    busy <= 0;
                    state <= S_IDLE;
                end
            endcase
        end
    end

    // SCLK 輸出控制
    always @(*) sd_sclk = ~spi_clk; 

endmodule