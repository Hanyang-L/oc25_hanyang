from microbit import *
import neopixel

np = neopixel.NeoPixel(pin8, 60)

for pixel_id in range(len(np)):
    np[pixel_id] = (0, 0, 6)
    np.show()
    sleep(1000)

