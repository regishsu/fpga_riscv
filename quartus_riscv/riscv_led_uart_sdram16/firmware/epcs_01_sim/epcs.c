/*

	change the IO base address 
	4-LED 7 segs 0x01000000
	Flash 0x02000000

*/

#include <stdint.h>
#include <stdbool.h>

// 定義硬體暫存器位址
#define reg_leds  (*(volatile unsigned int*)0x01000000)
#define reg_spictrl   (*(volatile unsigned int*)0x02000000) // Flash 映射起始點
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data (*(volatile uint32_t*)0x02000008)

// 七段顯示器編碼表 (共陽極或共陰極請根據你的硬體調整)
// 這裡假設是之前的編碼：0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C, D, E, F
unsigned char seg8_table[] = {
    0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xf8, 
    0x80, 0x90, 0x88, 0x83, 0xc6, 0xa1, 0x86, 0x8e
};


// --- 顯示邏輯 ---
void display_7segs(unsigned int value) {	
        unsigned int display_val = 0;

    // 拆解 value 並查表轉換成段碼
    // 第 1 顆 (bit 7:0)：低位數
    display_val |= (seg8_table[value & 0x000F] << 0);
        
    // 第 2 顆 (bit 15:8)
    display_val |= (seg8_table[(value >> 4) & 0x000F] << 8);
        
    // 第 3 顆 (bit 23:16)
    display_val |= (seg8_table[(value >> 8) & 0x000F] << 16);
       
    // 第 4 顆 (bit 31:24)：高位數
    display_val |= (seg8_table[(value >> 12) & 0x000F] << 24);
    reg_leds = display_val;
}

// 簡易延遲函式
void delay(volatile int count) {
    while (count--) {
        __asm__("nop");
    }
}

// --------------------------------------------------------

void putchar(char c)
{
	if (c == '\n')
		putchar('\r');
	reg_uart_data = c;
}

void print(const char *p)
{
	while (*p)
		putchar(*(p++));
}

void print_hex(uint32_t v, int digits)
{
	for (int i = 7; i >= 0; i--) {
		char c = "0123456789abcdef"[(v >> (4*i)) & 15];
		if (c == '0' && i >= digits) continue;
		putchar(c);
		digits = i;
	}
}

void print_dec(uint32_t v)
{
	if (v >= 1000) {
		print(">=1000");
		return;
	}

	if      (v >= 900) { putchar('9'); v -= 900; }
	else if (v >= 800) { putchar('8'); v -= 800; }
	else if (v >= 700) { putchar('7'); v -= 700; }
	else if (v >= 600) { putchar('6'); v -= 600; }
	else if (v >= 500) { putchar('5'); v -= 500; }
	else if (v >= 400) { putchar('4'); v -= 400; }
	else if (v >= 300) { putchar('3'); v -= 300; }
	else if (v >= 200) { putchar('2'); v -= 200; }
	else if (v >= 100) { putchar('1'); v -= 100; }

	if      (v >= 90) { putchar('9'); v -= 90; }
	else if (v >= 80) { putchar('8'); v -= 80; }
	else if (v >= 70) { putchar('7'); v -= 70; }
	else if (v >= 60) { putchar('6'); v -= 60; }
	else if (v >= 50) { putchar('5'); v -= 50; }
	else if (v >= 40) { putchar('4'); v -= 40; }
	else if (v >= 30) { putchar('3'); v -= 30; }
	else if (v >= 20) { putchar('2'); v -= 20; }
	else if (v >= 10) { putchar('1'); v -= 10; }

	if      (v >= 9) { putchar('9'); v -= 9; }
	else if (v >= 8) { putchar('8'); v -= 8; }
	else if (v >= 7) { putchar('7'); v -= 7; }
	else if (v >= 6) { putchar('6'); v -= 6; }
	else if (v >= 5) { putchar('5'); v -= 5; }
	else if (v >= 4) { putchar('4'); v -= 4; }
	else if (v >= 3) { putchar('3'); v -= 3; }
	else if (v >= 2) { putchar('2'); v -= 2; }
	else if (v >= 1) { putchar('1'); v -= 1; }
	else putchar('0');
}

char getchar_prompt(char *prompt)
{
	int32_t c = -1;

	uint32_t cycles_begin, cycles_now, cycles;
	__asm__ volatile ("rdcycle %0" : "=r"(cycles_begin));

	reg_leds = ~0;

	if (prompt)
		print(prompt);

	while (c == -1) {
		__asm__ volatile ("rdcycle %0" : "=r"(cycles_now));
		cycles = cycles_now - cycles_begin;
		if (cycles > 12000000) {
			if (prompt)
				print(prompt);
			cycles_begin = cycles_now;
			reg_leds = ~reg_leds;
		}
		c = reg_uart_data;
	}

	reg_leds = 0;
	return c;
}

char getchar()
{
	return getchar_prompt(0);
}

void cmd_echo()
{
	print("Return to menu by sending '!'\n\n");
	char c;
	while ((c = getchar()) != '!')
		putchar(c);
}

// real delay: 5000000
// simulation:5
#define DELAY 5
int main() {
	delay(DELAY);
	
	reg_uart_clkdiv = 434; //50MHz時鐘，想要 115200 bps：50,000,000/115,200 = 434
	print("Booting..\n");
	
	while (1) {
		display_7segs(0x0123);
		print("0x0123..\n");
		delay(DELAY);
		display_7segs(0x4567);
		print("0x4567..\n");
		delay(DELAY);
		display_7segs(0x89AB);
		print("0x89AB..\n");		
		delay(DELAY);
		display_7segs(0xCDEF);
		print("0xCDEF..\n");
		delay(DELAY);
		print("Return..\n");		
	}
    return 0;
}
