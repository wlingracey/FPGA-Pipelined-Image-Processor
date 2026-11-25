# Pipelined FPGA Sobel Edge Detection Engine

A streaming hardware image processing accelerator implemented in **SystemVerilog** on an **iCEBreaker v1.1a FPGA** (Lattice iCE40UP5K) with a Python/OpenCV UART host interface.

The design receives 640×480 RGB pixel frames streamed over a **115,200-baud UART** link, converts incoming pixels to 8-bit luminance, computes horizontal and vertical Sobel gradients ($G_x$, $G_y$) across a 3×3 sliding window backed by line buffers, and approximates edge magnitude ($\sqrt{G_x^2 + G_y^2}$) using signed fixed-point arithmetic and a 256-entry lookup table.

---

## Repository Structure

```text
FPGA-Pipelined-Image-Processor/
├── RTL/
│   ├── rgb2gray.sv        # Streaming RGB-to-grayscale luminance converter
│   ├── sobel.sv           # Line-buffered 3x3 Sobel Gx/Gy gradient filter
│   ├── mag.sv             # Signed squared-gradient sum & LUT square-root magnitude stage
│   ├── sqrt.hex           # 256-entry precomputed square-root lookup table
│   ├── elastic.sv         # AXI-Stream elastic pipeline register / skid buffer
│   ├── ram_1r1w_async.sv  # 1-read, 1-write memory block for scanline buffering
│   ├── uart_axis.sv       # 115,200-baud UART-to-AXI-Stream transceiver bridge
│   └── icebrk.bin         # Pre-compiled Lattice iCE40UP5K bitstream
├── Python/
│   └── run_fpga.py        # Host OpenCV/pySerial 640x480 UART frame streamer & unpacker
├── Images/
│   ├── car.jpg            # Original input test image
│   └── output_car.jpg     # Hardware-processed Sobel edge output
├── LICENSE
└── README.md
```

---

## Hardware Architecture

### Image Processing Pipeline
1. **RGB-to-Grayscale (`RTL/rgb2gray.sv`)**
   * Unpacks 24-bit RGB pixels (`[23:16]` R, `[15:8]` G, `[7:0]` B) and computes fixed-point luminance to output an 8-bit grayscale stream.
2. **3×3 Line-Buffered Sobel Filter (`RTL/sobel.sv`)**
   * Uses dual scanline buffers (`linewidth_px_p - 1` depth for 640-pixel rows) and rolling column counters (`linewidth_px_p - 2`) to form a 3×3 spatial sliding window on every valid pixel transfer.
   * Computes signed 11-bit horizontal ($G_x$) and vertical ($G_y$) convolution kernels across the 3×3 neighborhood.
3. **Gradient Magnitude Approximation (`RTL/mag.sv` & `RTL/sqrt.hex`)**
   * Computes $G_x^2 + G_y^2$ using `$signed()` arithmetic and indexes a 256-entry ROM (`sqrt.hex`) via the upper 8 bits (`plus_w[20:13]`) to approximate $\sqrt{G_x^2 + G_y^2}$ without DSP-heavy iterative dividers, outputting a 16-bit edge magnitude word per pixel.

### Transport & Buffering Modules
* **AXI-Stream Elastic Buffer (`RTL/elastic.sv`):** Decouples `valid`/`ready` handshaking between pipeline stages so backpressure propagates cleanly without dropping pixels.
* **Scanline Memory (`RTL/ram_1r1w_async.sv`):** Provides 1-read, 1-write storage backing the row buffers in `sobel.sv`.
* **UART-to-AXI-Stream Bridge (`RTL/uart_axis.sv`):** Operates in the 12 MHz iCEBreaker clock domain at 115,200 baud, deserializing incoming 4-byte RGB pixel packets from the host and serializing 16-bit magnitude responses back over USB-UART.

---

## Hardware Verification & Output (`Images/`)

`Python/run_fpga.py` resizes an input frame to `640×480`, packs each pixel into a 4-byte word (`[R, G, B, 0x00]`), streams rows over `pyserial` at `115200` baud to the iCEBreaker, and reconstructs the returned 16-bit edge magnitude map:

| Input Frame (`Images/car.jpg`) | Hardware Sobel Output (`Images/output_car.jpg`) |
| :---: | :---: |
| ![Input Image](Images/car.jpg) | ![Hardware Sobel Output](Images/output_car.jpg) |

---

## Flashing & Running

### 1. Flash Pre-Compiled Bitstream (iCEBreaker v1.1a)
```bash
openFPGALoader -b ice40_generic RTL/icebrk.bin
```

### 2. Stream an Image from the Host
```bash
pip install opencv-python numpy pyserial
python3 Python/run_fpga.py
```
*(Update the serial port path in `Python/run_fpga.py`—such as `/dev/cu.usbserial-*` on macOS or `/dev/ttyUSB*` on Linux—to match your iCEBreaker FTDI interface.)*

### Synthesis Note
To synthesize the `.sv` files from source using **Yosys**, **nextpnr-ice40**, and **IceStorm**, provide a top-level wrapper connecting `uart_axis` → `rgb2gray` → `sobel` → `mag`, standard edge-triggered register primitives (`dff`), and an iCEBreaker `.pcf` constraint file mapping the 12 MHz clock and USB-UART pins.

---

## Acknowledgments
* **Toolchain & Architecture:** Developed within a modular AXI-Stream FPGA design workflow inspired by the open-source iCEBreaker digital logic curriculum created by **Professor Dustin Richmond** (UCSC Baskin School of Engineering).
