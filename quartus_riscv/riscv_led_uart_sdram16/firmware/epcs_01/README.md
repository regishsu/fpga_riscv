#在Windows的wsl2環境 or ubuntu

#install riscv complier tools
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf

#build firmware to mif format and copy to ../../soc folder
make clean
make 

# review the assemble code while built ok
riscv64-unknown-elf-objdump -d hello.elf | head -n 60
