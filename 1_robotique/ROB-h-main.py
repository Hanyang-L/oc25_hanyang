"""
TP robot

Nom: ...
Classe: ...
Date: ...
No du robot: ...

Dans ce TP vous allez apprendre comment
- contrôler 2 moteurs
- analyser et documenter les traces du robot
- programmer le mouvement du robot
- lire les capteurs optiques
- s'arrêter au bord de la table
- suivre une ligne
- utiliser la communication radio pour créer une télécommande
"""

from microbit import *
import KitronikMOVEMotor
import music
import radio

robot = KitronikMOVEMotor.MOVEMotor()
robot.move(0, 0)

radio.on()
radio.config(group=1)

prog = 0 # programme actuel (0..9)
display.show(prog)

while True:
    # le bouton A incrémente les programmes (0..9)
    if button_a.was_pressed():
        robot.move(0, 0)
        prog = (prog + 1) % 10
        display.show(prog)
        music.pitch(440, 20)
        print('prog =', prog)
    
    # dessiner un trait, mesurer la distance, calculer la vitesse
    if prog == 0:
        if button_b.is_pressed():
            robot.move(80, 80, 1000)
            robot.move(-80, -80, 500)

    # dessiner un V, mesurer l'angle
    if prog == 1:
        if button_b.is_pressed():
            robot.move(80, 80, 1000)
            sleep(50)
            robot.move(80, -80, 1000)
            sleep(50)
            robot.move(80, 80, 1000)
            
    # dessiner un S, mesurer l'angle de l'arc
    if prog == 2:
        if button_b.is_pressed():
            robot.move(0,80, 2000)
            sleep(50)
            robot.move(80, 0, 2000)
            
    # dessiner un triangle
    if prog == 3:
        if button_b.is_pressed():
            for i in range(3):
                robot.move(79, 79, 1000)
                sleep(50)
                robot.move(79, -79, 1000)
                sleep(50)
                

    # dessiner un hexagone
    if prog == 4:
        if button_b.is_pressed():
            for i in range(6):
                robot.move(79, 79, 1000)
                sleep(50)
                robot.move(79,-79, 2000)
                sleep(50)

    # lire les 2 capteurs de lumière
    if prog == 5:
        if button_b.is_pressed():
            left = pin1.read_analog()
            right = pin2.read_analog()
            print(left, right)
            sleep(200)

    # s'arrêter au bord de la table
    if prog == 6:
        if button_b.is_pressed():
            music.pitch(880, 10)
            robot.move(80, 80)

        left = pin1.read_analog()
        right = pin2.read_analog()
        if left < 100 or right < 100:
            robot.move(0, 0)

    # suivre une ligne
    if prog == 7:
        left = pin1.read_analog()
        right = pin2.read_analog()
        d = (left - right)
        d = d // 10
        robot.move(10 - d, 10 + d)

    # télécommander le robot avec un 2e micro:bit
    if prog == 8:
        msg = radio.receive()
        if msg:
            display.show(msg)
            if msg == '0':
                robot.move(0, 0)
            elif msg == 'u':
                robot.move(100, 100)
            elif msg == 'r':
                ...
            elif msg == 'l':
                ...
            elif msg == 'd':
                ...
            elif msg == '2':
                music.play(music.BA_DING)
            elif msg == '1':
               ...