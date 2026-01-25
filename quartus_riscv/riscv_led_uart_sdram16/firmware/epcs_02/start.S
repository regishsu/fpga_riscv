.section .vectors
.global _start
_start:
    li sp, 0x00002000    /* 將堆疊指標指向 8KB RAM 的頂端 */
    call main            /* 跳轉到 C 語言的 main */
loop:
    j loop               /* 防止 main 結束後 CPU 亂跑 */

