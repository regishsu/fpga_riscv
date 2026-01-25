module spi_bus_wrapper (
    input wire clk,
    input wire rst_n,
    
    // PicoRV32 介面
    input wire        mem_valid,
    input wire [31:0] mem_addr,
    input wire [31:0] mem_wdata,
    input wire [3:0]  mem_wstrb,
    output wire [31:0] mem_rdata, // 改成 wire
    output wire        mem_ready, // 改成 wire

    // 連接到 SPI 控制器實體
    output reg [23:0] spi_addr,
    output reg        spi_trigger,
    input wire [7:0]  spi_data_in,
    input wire        spi_busy
);

    // 位址解碼
    wire sel = (mem_addr[31:16] == 16'h2000);
    
    // 只有在位址正確且有效時才給予 ready
    assign mem_ready = sel && mem_valid;

    // 讀取資料的組合邏輯 (Mux)
    assign mem_rdata = (mem_addr[3:0] == 4'h8) ? {24'b0, spi_data_in} :
                       (mem_addr[3:0] == 4'hC) ? {31'b0, spi_busy}    : 32'h0;

    // 處理寫入暫存器 (控制線)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_trigger <= 0;
            spi_addr <= 0;
        end else begin
            if (sel && mem_valid && (|mem_wstrb)) begin
                case (mem_addr[3:0])
                    4'h0: spi_trigger <= mem_wdata[0];
                    4'h4: spi_addr    <= mem_wdata[23:0];
                endcase
            end
        end
    end
endmodule