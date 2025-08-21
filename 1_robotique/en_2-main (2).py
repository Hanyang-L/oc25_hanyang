# Imports go at the top
from microbit import *
import speech
import music

p=0

while True:
    display.show(p)
    if button_a.was_pressed():
        p=p+1
        if p==10:
            p=0
    if button_b.was_pressed():
        p=p-1
        if p == -1:
            p=9


    if pin_logo.is_touched():
        if p==0:
            display.show(Image.SMILE)
            sleep(1000)
        elif p==1:
            display.scroll('H')
            sleep(1000)
        elif p==2:
            set_volume(120)
            speech.say('no')
        elif p==3:
            music.play(['c', 'd', 'e', 'c'])
            










