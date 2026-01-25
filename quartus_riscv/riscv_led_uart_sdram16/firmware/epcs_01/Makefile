# --- 工具鏈設定 ---
CROSS_COMPILE = riscv64-unknown-elf-
CC      = $(CROSS_COMPILE)gcc
AS      = $(CROSS_COMPILE)as
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

# --- 專案檔案設定 ---
TARGET = epcs
SRCS   = start.S epcs.c
OBJS   = start.o epcs.o
LDS    = sections.lds

# --- 編譯參數 ---
CFLAGS  = -march=rv32i -mabi=ilp32 -O2 -ffreestanding -Wall
LDFLAGS = -march=rv32i -mabi=ilp32 -nostdlib -Wl,-T,$(LDS)

# --- 生成目標 ---
# 新增 $(TARGET).mif 到 all 中
all: $(TARGET).elf $(TARGET).bin $(TARGET).mif
	@echo "------------------------------------------------"
	@echo "Build Done: $(TARGET).mif generated."
	@echo "Copying $(TARGET).mif to soc directory as epcs.mif..."
	@cp $(TARGET).mif ../../soc/epcs.mif
	@echo "Check entry point with: $(OBJDUMP) -d $(TARGET).elf | head -n 60"

# 將 ELF 轉換為 Binary
$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

# 【核心部分】將 Binary 轉換為 MIF 格式
# DEPTH 為 2048 (對應 8KB RAM)，WIDTH 為 32 (位元)
$(TARGET).mif: $(TARGET).bin
	@echo "Generating $@..."
	@printf "DEPTH = 2048;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\n\nCONTENT\nBEGIN\n" > $@
	@hexdump -v -e '1/4 "%08X" "\n"' $< | \
	 awk '{printf "%03X : %s;\n", NR-1, $$1}' >> $@
	@echo "END;" >> $@

# 連結
$(TARGET).elf: $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

# 編譯 C 檔案
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# 編譯組合語言檔案
%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s
	$(CC) $(CFLAGS) -c $< -o $@
	
# 清理檔案
clean:
	rm -f *.o *.elf *.hex *.bin *.mif

.PHONY: all clean
