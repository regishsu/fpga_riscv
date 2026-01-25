MEMORY
{
    /* 確保這是在 0 位址，且長度與你的 BRAM 一致 */
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0x2000 
}

SECTIONS
{
    .text : {
        *(.vectors)   /* 確保中斷向量或啟動代碼在最前面 */
        *(.text)
        . = ALIGN(16);
    } > ram
}
