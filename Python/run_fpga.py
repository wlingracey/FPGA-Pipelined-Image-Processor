import sys # for selecting file?
import cv2 as cv # opencv? reads, resizing, saving
import numpy as np # for array stuff
import serial # uart stuff

# receive image filename, if no file given just use default car option
img_name = sys.argv[1] if len(sys.argv) > 1 else "car.jpg"
# set the name of the outputted file
out_name = "output_" + img_name

# UART stuff from cocotb stuff
ser = serial.Serial("/dev/cu.usbserial-ibltle3L1", 115200, timeout=2)

# load image using the 3 rgb channels BUT WITH BLUE GREEN RED ORDER
src = cv.imread(img_name, cv.IMREAD_COLOR)
# src = image shrunk down to 640 x 480
src = cv.resize(src, (640, 480))

# convert color order from bgr to rgb
rgb = cv.cvtColor(src, cv.COLOR_BGR2RGB)
# create the grid for the last padding byte of each pixel
zeros = np.zeros((480, 640, 1), dtype=np.uint8)
# concat 3 rgb bytes with pad byte for 4 byte pixels R G B 0
tx_data = np.concatenate((rgb, zeros), axis=2)

# create empty buffer for processed bytes
rx_bytes = bytearray()
# loop through the rows
for r in range(480):
    # convert row to raw bytes
    ser.write(tx_data[r].tobytes())
    # read back processed bytes for the row from fpga
    rx_bytes.extend(ser.read(2560))
    # progress display
    print(f"Row {r + 1}/480")
# close serial port
ser.close()
# take unsigned 16 bit ints and reshape, 32 bit pixels split into 16 bit ints
words = np.frombuffer(rx_bytes, dtype=np.uint16).reshape((480, 640, 2))
# take lower 16 bits to extract magnitude for each pixel
mag = words[:, :, 0]
# limit every mag value to 255, convert to unsigned 8 bit ints
mag_img = np.clip(mag, 0, 255).astype(np.uint8)
# save final image
cv.imwrite(out_name, mag_img)
# save confirmation
print(f"Saved {out_name}")
