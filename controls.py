#! /usr/bin/env python3
# Bookshelf jukebox controls

from gpiozero import Button, RotaryEncoder
from signal import pause
import os
import time
import settings
from functions import *

##########################################################################################################
####### DONT CHANGE THE SETTINGS INBETWEEN THESE LINES. INSTEAD CHANGE THE SETTINGS IN SETTINGS.PY #######

# Pin numbers on Raspberry Pi
CLK_PIN = settings.CLK_PIN                          # GPIO7 connected to the rotary encoder's CLK pin
DT_PIN = settings.DT_PIN                            # GPIO8 connected to the rotary encoder's DT pin
SW_PIN = settings.SW_PIN                            # GPIO5 connected to the rotary encoder's SW pin
NEXT_PIN = settings.NEXT_PIN                        # GPIO12 connected to the next song touch button pin
PREV_PIN = settings.PREV_PIN                        # GPIO16 connected to the previous song touch button pin

# Times for button presses
SHORT_PRESS_TIME = settings.SHORT_PRESS_TIME        # Time for shortpress in seconds
LONG_PRESS_TIME = settings.LONG_PRESS_TIME          # Time for longpress in seconds
DEBOUNCE_TIME = settings.DEBOUNCE_TIME / 1000.0     # Convert ms to seconds

# Volume steps
VOLUME_ADJUSTEMENT = settings.VOLUME_ADJUSTEMENT    # How much to add to the volume every step. Range: 0-100

# At boot there is no playlist yet. For autoplay library radio to work you need the machineIdentifier of your plexserver
PLEX_ID = settings.PLEX_ID                          # Find the machineIdentifier at http://[IP address]:32400/identity/
AUTOPLAY = settings.AUTOPLAY                        # 0 = Autoplay on start, 1 = No autoplay on start
START_VOLUME = settings.START_VOLUME                # Set volume level at start Range: 1-100, 0 = disable

####### DONT CHANGE THE SETTINGS INBETWEEN THESE LINES. INSTEAD CHANGE THE SETTINGS IN SETTINGS.PY #######
##########################################################################################################

# General variables
is_long_press = False

###################################################
### Autoplay functionality ########################
###################################################
def autoplay():
    if AUTOPLAY == 0 and PLEX_ID != '':                     # Check if autoplay is enabled and a PLEX ID is present
        if START_VOLUME >= 1 and START_VOLUME <= 100:       # Check if there is a start volume set
            setState(START_VOLUME)                          # Set start volume
        setState('playMedia')                               # Start playback

###################################################
### Rotary encoder functionality ##################
###################################################
def vol_up():
    setState('volUp')

def vol_down():
    setState('volDown')

# Initialize Rotary Encoder
# Note: direction might need swapping depending on wiring. 
# Adjust logic or swap callbacks if needed.
rotary = RotaryEncoder(CLK_PIN, DT_PIN, bounce_time=0.01)
rotary.when_rotated_clockwise = vol_up
rotary.when_rotated_counter_clockwise = vol_down

###################################################
### Rotary button functionality ###################
###################################################
def shutdown():
    global is_long_press
    is_long_press = True
    setState('stop')                                # Stop playing
    os.system('sudo shutdown -h now')               # Shutdown system

def handle_sw_release():
    global is_long_press
    if not is_long_press:
        # Short press action
        if getState('state') == 'stopped':               # Check if current state is stopped
            setState('playMedia')                        # Start playback
        else:
            setState('playPause')                        # Pause playback
    
    is_long_press = False # Reset flag

sw_button = Button(SW_PIN, pull_up=True, bounce_time=DEBOUNCE_TIME, hold_time=LONG_PRESS_TIME)
sw_button.when_held = shutdown
sw_button.when_released = handle_sw_release

###############################################
### Touch next/prev button functionality ######
###############################################
def handle_next():
    setState('next')

def handle_prev():
    setState('prev')

next_btn = Button(NEXT_PIN, pull_up=True, bounce_time=DEBOUNCE_TIME)
next_btn.when_pressed = handle_next

prev_btn = Button(PREV_PIN, pull_up=True, bounce_time=DEBOUNCE_TIME)
prev_btn.when_pressed = handle_prev

###################################################
### Autoplay at startup if enabled ################
###################################################
autoplay()

# Keep script running
pause()