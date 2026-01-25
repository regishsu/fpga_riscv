[fpga]
#cyclone iv ep4ce6e22c8, with 4 digits 7 seg led, uart, 64mbit sdram
#dev tools, intel Quartus Prime 25.1 free version
build the fpga code:
1. open project riscv.qpf: from quartus manu, file->open project, select "riscv.qpf"
2. build the firmware as [firmware] below section.
3. push "start compilation", 
4. and then use "programmer" writes to fpga board
*notice: review the pin assigment to fit you board

you can see the 4digit-led shows "1234"->"5678"->...->"CDEF".
and the same messge to uart with bauf-rate 115200.

test-bench:
1. the same as build the fpga code process 1/2/3,
2. use epcs01_sim firmware.
2. from quartus manu, tools->run simuation tool->RTL simulation.
you can see the some pins wave. you can ask AI-LLM more instruction.

[firmware]
#在Windows的wsl2環境 or ubuntu

#install riscv complier tools
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf

#build firmware to mif format and copy to ../../soc folder
make clean
make 

# review the assemble code while built ok
riscv64-unknown-elf-objdump -d hello.elf | head -n 60
