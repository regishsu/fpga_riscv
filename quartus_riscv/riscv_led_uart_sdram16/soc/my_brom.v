module my_brom (
    input [10:0] address,   // 2048 words needs 11-bit
    input [3:0]  byteena,
    input        clock,
    input [31:0] data,
    input        wren,
    output reg [31:0] q
);
    // 宣告 2048 x 32-bit 的記憶體陣列
    reg [31:0] ram [0:2047];

    // 初始化：載入 Firmware
    initial begin
        $readmemh("hello.hex", ram);
    end

    // 處理寫入 (支援 Byte Enable)
    always @(posedge clock) begin
        if (wren) begin
            if (byteena[0]) ram[address][7:0]   <= data[7:0];
            if (byteena[1]) ram[address][15:8]  <= data[15:8];
            if (byteena[2]) ram[address][23:16] <= data[23:16];
            if (byteena[3]) ram[address][31:24] <= data[31:24];
        end
        // 處理讀取 (同步讀取)
        q <= ram[address];
    end
endmodule
