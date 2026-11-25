# Pipelined FPGA Sobel Edge Detection Engine

A streaming hardware image processing accelerator implemented in **SystemVerilog** on an **iCEBreaker v1.1a FPGA** (Lattice iCE40UP5K) with a Python/OpenCV UART host interface.

The accelerator receives 640×480 RGB pixel frames streamed from a host machine over a **115,200-baud UART** link, converts each pixel to 8-bit luminance, computes horizontal and vertical Sobel gradients ($G_x$, $G_y$) across a 3×3 sliding window backed by dual synchronous line buffers, and approximates edge magnitude ($\sqrt{G_x^2 + G_y^2}$) using signed fixed-point arithmetic and a 256-entry lookup table.

---

## Repository Structure

```text
FPGA-Pipelined-Image-Processor/
├── RTL/
│   ├── rgb2gray.sv        # Streaming RGB-to-grayscale luminance stage
│   ├── sobel.sv           # Dual line-buffered 3x3 Sobel Gx/Gy gradient filter
│   ├── mag.sv             # Signed squared-gradient sum & LUT square-root magnitude stage
│   └── sqrt.hex           # 256-entry precomputed square-root lookup table
├── Python/
│   └── run_fpga.py        # Host OpenCV/pySerial 640x480 UART frame streamer & unpacker
├── Images/
│   ├── car.png          # Original 640x480 test frame
│   └── output_car.png   # Hardware-processed Sobel edge map
├── LICENSE
└── README.md
```

---

## Hardware Pipeline Architecture

The datapath operates as a three-stage streaming pipeline using standard `valid`/`ready`/`data` AXI-Stream handshaking so backpressure propagates cleanly from output to input without dropping pixels:

1. **RGB-to-Grayscale (`rtl/rgb2gray.sv`)**
   * Accepts packed 24-bit RGB pixels (`[23:16]` R, `[15:8]` G, `[7:0]` B) and computes fixed-point luminance to output an 8-bit grayscale stream.
2. **3×3 Line-Buffered Sobel Filter (`rtl/sobel.sv`)**
   * Maintains two row buffers (`linewidth_px_p - 1` depth for 640-pixel scanlines) synchronized via rolling column counters (`linewidth_px_p - 2`) to form a 3×3 spatial sliding window on every valid pixel advance.
   * Computes signed 11-bit horizontal ($G_x$) and vertical ($G_y$) convolution kernels across the 3×3 neighborhood.
3. **Gradient Magnitude Approximation (`rtl/mag.sv` & `rtl/sqrt.hex`)**
   * Computes $G_x^2 + G_y^2$ using `$signed()` arithmetic and indexes a 256-entry ROM (`sqrt.hex`) via the upper 8 bits (`plus_w[20:13]`) to approximate $\sqrt{G_x^2 + G_y^2}$ without DSP-heavy iterative dividers, returning a 16-bit edge magnitude word per pixel.

---

## External Interfaces & Dependencies (Standalone RTL Disclosure)

To keep this repository focused strictly on original RTL and host software, course-provided build infrastructure and standard synchronous library primitives are intentionally omitted. As a result, the modules in `rtl/` will not synthesize standalone without supplying compatible wrappers for the following interfaces:

* **Synchronous Memory & Register Primitives:**
  * `ram_1r1w_sync`: Synchronous 1-read, 1-write block RAM primitive instantiated by `sobel.sv` for scanline buffering (`width_p = 8`, `depth_p = linewidth_px_p - 1`).
  * `dff`: Standard positive-edge-triggered D flip-flop primitive used across pipeline stages.
* **Top-Level Transport & Board Constraints:**
  * `uart_axis`: 115,200-baud UART-to-AXI-Stream bridge (12 MHz system clock domain) that deserializes incoming 4-byte pixel words (`[R, G, B, 0]`) into the `rgb2gray` input stream and serializes 16-bit magnitude responses from `mag` back to the host.
  * **Build Flow & Pinout:** Originally synthesized for the **iCEBreaker v1.1a (`iCE40UP5K-SG48`)** using **Yosys**, **nextpnr-ice40**, and **IceStorm** with standard USB-UART pin constraints (`uart_rx` / `uart_tx`).

---

## Host Verification (`scripts/run_fpga.py`)

`run_fpga.py` drives end-to-end hardware verification from macOS/Linux over USB-UART:

1. Loads an input image via OpenCV (`cv2`), resizes it to `640×480`, and packs each pixel into a 4-byte frame (`[R, G, B, 0x00]`).
2. Streams rows over `pyserial` at `115200` baud to the FPGA and reads back the corresponding 16-bit edge magnitude words.
3. Reconstructs and saves the resulting 640×480 edge-detected frame (see `examples/`).

```bash
pip install opencv-python numpy pyserial
python3 scripts/run_fpga.py
```
*(Update the serial device path in `run_fpga.py`—e.g., `/dev/cu.usbserial-*` on macOS or `/dev/ttyUSB*` on Linux—to match your iCEBreaker FTDI interface.)*

---

## Acknowledgments
* **Toolchain & Primitive Architecture:** Built within a modular AXI-Stream FPGA design flow inspired by the open-source iCEBreaker curriculum developed by **Professor Dustin Richmond** (UCSC Baskin School of Engineering).
