#! /usr/bin/env python3
# Bookshelf jukebox controls

from gpiozero import Button, RotaryEncoder, OutputDevice
from signal import pause
import os
import time
import threading
import requests
import settings
from functions import getState

##########################################################################################################
####### DONT CHANGE THE SETTINGS INBETWEEN THESE LINES. INSTEAD CHANGE THE SETTINGS IN SETTINGS.PY #######

# Pin numbers on Raspberry Pi
CLK_PIN = settings.CLK_PIN                          # GPIO7 connected to the rotary encoder's CLK pin
DT_PIN = settings.DT_PIN                            # GPIO8 connected to the rotary encoder's DT pin
SW_PIN = settings.SW_PIN                            # GPIO5 connected to the rotary encoder's SW pin
NEXT_PIN = settings.NEXT_PIN                        # GPIO12 connected to the next song touch button pin
PREV_PIN = settings.PREV_PIN                        # GPIO16 connected to the previous song touch button pin
SCREEN_PIN = settings.SCREEN_PIN                    # GPIO23 connected to the screen backlight pin

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

# Screen backlight control
SCREEN_TIMEOUT = settings.SCREEN_TIMEOUT            # Turn screen backlight off after * minutes

####### DONT CHANGE THE SETTINGS INBETWEEN THESE LINES. INSTEAD CHANGE THE SETTINGS IN SETTINGS.PY #######
##########################################################################################################

# General variables
is_long_press = False

# Initialize Output Devices
# Active Low logic: active_high=False, initial_value=True -> Starts "Active" (LOW) which is ON.
screen = OutputDevice(SCREEN_PIN, active_high=False, initial_value=True)

###################################################
### Helper Functions (Moved from functions.py) ####
###################################################

def setScreen(ACTION):
    if ACTION == 'on':
        screen.on()
    elif ACTION == 'off':
        screen.off()

def setState(CONTROL):
    action = None
    if CONTROL == 'playMedia' and PLEX_ID != '':
        action = f'playMedia?uri=server%3A%2F%2F{PLEX_ID}%2Fcom.plexapp.plugins.library%2Flibrary%2Fsections%2F15%2Fstations%2F1'
    elif CONTROL == 'playPause':
        action = 'playPause'
    elif CONTROL == 'stop':
        action = 'stop'
    elif CONTROL == 'next':
        action = 'skipNext'
    elif CONTROL == 'prev':
        action = 'skipPrevious'
    elif CONTROL == 'volUp':
        current_vol = getState('volume')
        if current_vol is not None:
            volume = current_vol + VOLUME_ADJUSTEMENT
            if volume > 100: volume = 100
            action = f'setParameters?volume={volume}'
    elif CONTROL == 'volDown':
        current_vol = getState('volume')
        if current_vol is not None:
            volume = current_vol - VOLUME_ADJUSTEMENT
            if volume < 0: volume = 0
            action = f'setParameters?volume={volume}'

    if action:
        try:
            requests.get(f'http://localhost:32500/player/playback/{action}')
            setScreen('on') # Wake screen on action
        except requests.exceptions.RequestException:
            pass
    return

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
### Screen Monitor Loop (Merged from screen.py) ###
###################################################
def monitor_job():
    SCREEN_TIMEOUT_START = time.time()
    PB_PREV_STATE = 'paused'
    setScreen('on')

    while True:
        try:
            current_state = getState('state')
            
            if current_state == 'playing':
                if PB_PREV_STATE != 'playing':
                    PB_PREV_STATE = 'playing'
                    setScreen('on')
            else:
                if PB_PREV_STATE == 'playing':
                    PB_PREV_STATE = 'paused'
                    SCREEN_TIMEOUT_START = time.time()
                
                # Check timeout
                screen_timeout_duration = time.time() - SCREEN_TIMEOUT_START
                if screen_timeout_duration > (SCREEN_TIMEOUT * 60):
                    setScreen('off')
        except Exception:
            pass

        time.sleep(5)

# Start monitor in a background thread
monitor_thread = threading.Thread(target=monitor_job, daemon=True)
monitor_thread.start()

###################################################
### Autoplay at startup if enabled ################
###################################################
autoplay()

# Keep script running
pause()