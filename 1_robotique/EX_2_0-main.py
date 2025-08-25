from microbit import *
import speech
import music

p=0
prenom = []

while True:
    
    display.show(p)
    if button_b.was_pressed():
        p=p+1
        if p==10:
            p=0
    if button_a.was_pressed():
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
            speech.say('nononononononononon')
            
        elif p==3:
            music.play(['c', 'd', 'e', 'c','c', 'd', 'e', 'c'])
            
        elif p==4:
            display.show(Image('70707:'
                               '70707:'
                               '77977:'
                               '70707:'
                               '70779'))
            sleep(2000)
            
        elif p==5:
            display.scroll(temperature())
            sleep(500)
            if temperature()<=25:
                display.scroll('COLD')
                
            else:
                display.scroll('HOT')
            sleep(1000)
            
        elif p==6:
            display.scroll(display.read_light_level())
            sleep(1000)
            
        elif p==7:
            n=0
            display.scroll('Choisi un nombre')
            while True:
                display.show(n)
                if button_b.was_pressed():
                    n=n+1
                    if n==10:
                         n=0
                if button_a.was_pressed():
                    n=n-1
                    if n == -1:
                        n=9
                if pin_logo.is_touched():
                    if n==4:
                        display.scroll('You won!!!')
                        break
                    else:
                        display.scroll('You lost!!!')
                        break
            sleep(1000)
            
        elif p==8:
            ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ "
            display.scroll("Prénom?")
            alph = 0
            while True:
                display.show(ALPHABET[alph])
                if button_b.was_pressed():
                    alph = (alph + 1) % len(ALPHABET)
                if button_a.was_pressed():
                    alph = (alph - 1) % len(ALPHABET)
                if pin_logo.is_touched():
                    prenom.append(ALPHABET[alph])
                    display.show(Image.HAPPY)
                    sleep(300)
                if button_a.is_pressed() and button_b.is_pressed():
                    display.scroll(''.join(prenom))
                    break
            sleep(80)
            
        elif p==9:
            speech.say(''.join(prenom))
            sleep(400)
            speech.say('How are you?')

        










