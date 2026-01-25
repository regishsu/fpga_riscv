module uart_tx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
)(
    input            clk,
    input            reset,
    input      [7:0] tx_data,
    input            tx_valid,
    output reg       tx_ready,
    output reg       uart_txd
);
    localparam DIV_WAIT = CLK_FREQ / BAUD_RATE;
    reg [15:0] clk_cnt;
    reg [3:0]  state; // 0:Idle, 1:Start, 2-9:Data, 10:Stop
    reg [7:0]  data_buf;

    initial uart_txd = 1'b1;
    initial tx_ready = 1'b1;

    always @(posedge clk) begin
        if (!reset) begin
            state <= 0;
            uart_txd <= 1'b1;
            tx_ready <= 1'b1;
        end else begin
            case (state)
                0: if (tx_valid) begin
                    data_buf <= tx_data;
                    state <= 1;
                    tx_ready <= 1'b0;
                    clk_cnt <= 0;
                end
                1: begin // Start bit (0)
                    uart_txd <= 1'b0;
                    if (clk_cnt == DIV_WAIT) begin state <= 2; clk_cnt <= 0; end
                    else clk_cnt <= clk_cnt + 1;
                end
                2,3,4,5,6,7,8,9: begin // Data bits
                    uart_txd <= data_buf[state-2];
                    if (clk_cnt == DIV_WAIT) begin state <= state + 1; clk_cnt <= 0; end
                    else clk_cnt <= clk_cnt + 1;
                end
                10: begin // Stop bit (1)
                    uart_txd <= 1'b1;
                    if (clk_cnt == DIV_WAIT) begin state <= 0; tx_ready <= 1'b1; end
                    else clk_cnt <= clk_cnt + 1;
                end
            endcase
        end
    end
endmodule