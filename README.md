
# [FPGA Development]

### **Hardware Specification**

* **Board:** Cyclone IV EP4CE6E22C8
* **Peripherals:** * 4-digit 7-segment LED display
* UART interface
* 64 Mbit SDRAM



### **Development Tools**

* **Software:** Intel Quartus Prime 25.1 (Lite/Free Edition)

---

## **Build Process**

### **1. Hardware Compilation**

1. **Compile Firmware:** Ensure the RISC-V firmware is built first (refer to the **[Firmware]** section below).
2. **Open Project:** In Quartus, go to `File` -> `Open Project` and select `riscv.qpf`.
3. **Start Compilation:** Click `Processing` -> `Start Compilation` (or use the shortcut `Ctrl+L`).
4. **Program FPGA:** Open `Tools` -> `Programmer` to write the compiled bitstream to your FPGA board.

> **Note:** Please review the **Pin Assignments** (`Assignments` -> `Assignment Editor`) to ensure they match your specific hardware layout.

### **2. Expected Result**

* **7-Segment LED:** The display will cycle through sequences: `1234` -> `5678` -> ... -> `CDEF`.
* **UART Output:** The same message will be sent via UART at a **baud rate of 115200**.

---

## **Simulation (Testbench)**

1. Follow the hardware build steps (1–3) as described above.
2. Ensure you are using the `epcs01_sim` firmware configuration.
3. Go to `Tools` -> `Run Simulation Tool` -> `RTL Simulation`.
4. The waveform viewer will open, allowing you to observe pin transitions and signal waves.
* *Tip: You can use AI-LLM tools to help interpret specific waveform behaviors.*



---

# [Firmware Development]

### **Environment Setup**

* **OS:** WSL2 (Windows Subsystem for Linux) or Native Ubuntu.

### **1. Install RISC-V Toolchain**

Run the following command to install the required compiler and utilities:

```bash
sudo apt update
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf

```

### **2. Build Firmware**

Generate the `.mif` (Memory Initialization File) and sync it to the SoC directory:

```bash
make clean
make

```

*The build script will automatically copy the generated files to the `../../soc` folder.*

### **3. Verification**

To inspect the generated assembly code and verify the build, use `objdump`:

```bash
# View the first 60 lines of the assembly code
riscv64-unknown-elf-objdump -d hello.elf | head -n 60

