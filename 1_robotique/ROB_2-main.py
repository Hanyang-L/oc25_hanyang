"""
TP Neopixel

Nom: Lin
Classe: 3M5
Date: 28.8.25

Dans ce TP vous aller apprendre
- comment analyser et documenter un programme
- comment représenter des couleurs en format RGB
- comment programmer des LED avec le module neopixel
- comment utiliser modulo (%) pour limiter une plage
- comment utiliser les boutons et les sons
"""

from microbit import *
import neopixel
import music
import random

red = (10, 0, 0)
green = (0, 10, 0)
blue = (0, 0, 10)

yellow = (10, 10, 0)
magenta = (10, 0, 10)
cyan = (0, 10, 10)
orange = (10, 5, 0)

black = (0, 0, 0)
gray = (5, 5, 5)
white = (10, 10, 10)

colors = (red, orange, yellow, green, cyan, blue, magenta)
color = cyan

np = neopixel.NeoPixel(pin8, 60)

prog = 0 # programme actuel (0..9)
i = 0    # indice de LED (0..59)
j = 0    # indice de couleur (0..6)

compass_on = False
display.show(prog)

while True:
    if button_a.was_pressed():
        prog = (prog + 1) % 10
        display.show(prog)
        np.clear()
        music.pitch(440, 20)

    if pin_logo.is_touched():
        j = (j + 1) % len(colors)
        music.pitch(100, 20)
        sleep(100)

    if i == 0:
        np.clear()
        music.pitch(100, 100)

    if prog == 0:
        np[i] = colors[j]
        np.show()
        sleep(500)
        i = (i + 1) % 60
    
    if prog == 1:
        np[i] = colors[j]
        np.show()
        sleep(20)
        np.clear()
        i = (i + 1) % 60  

    if prog == 2:
        j = i % len(colors)
        np[i] = colors[j]
        i = (i + 1) % 60
        sleep(50)
        np.show()

    if prog == 3:
        if button_b.is_pressed():
            i = i - 1
        else:
            i = i + 1
        i = i % 30
        np.clear()
        np[i] = colors[j]
        np.show()
        sleep(20)
        
    if prog == 4:
        ...

    if prog == 5:
        ...
     
    if prog == 6:
        i = (i+1) % 20
        np[i] = (20-i, i, 0)
        np[i+20] = (0, 20-i, i)
        np[i+40] = (i, 0, 20-i)
        sleep(50)
        np.show()

    if prog == 7:
        ...

    if prog == 8:
        t = running_time()
        i = (t % 1000) // 17
        i2 = (t//1000) % 60
        np.clear()
        np[i] = red
        np[i2] = green
        np.show()

    if prog == 9:
        if button_b.is_pressed():
            compass_on = True
        if compass_on:
            i = 59 - compass.heading() // 6
            np.clear()
            np[i] = red
            np[(i+30)%60] = blue
            np.show()
            sleep(20)