#! /usr/bin/env python3
# Bookshelf jukebox functions


from gpiozero import OutputDevice
import requests
import settings
import xml.etree.ElementTree as ET


# Get the settings
PLEX_ID = settings.PLEX_ID
VOLUME_ADJUSTEMENT = settings.VOLUME_ADJUSTEMENT

# Pin numbers on Raspberry Pi
SCREEN_PIN = settings.SCREEN_PIN             # GPIO23 connected to the screen backlight pin

# Configure GPIO pins
# Active Low logic based on original: setup(LOW) -> On? 
# Original: setup(SCREEN_PIN, GPIO.LOW). 
# setScreen('on') -> output(LOW).
# setScreen('off') -> output(HIGH).
# So LOW is ON. active_high=False.
# initial_value=True means "Active" (LOW) at start.
screen = OutputDevice(SCREEN_PIN, active_high=False, initial_value=True)


############################################################
# Function for getting the current state from Plexamp ######
############################################################
def getState(TYPE):
    # Poll for the state of Plexamp
    try:
        getState = requests.get('http://localhost:32500/player/timeline/poll?wait=0&includeMetadata=0&commandID=1')
        if getState.ok:
            content = getState.content
            root = ET.fromstring(content)

            # Search the poll state data for the timeline
            for type_tag in root.findall('Timeline'):
                item_type = type_tag.get('itemType')
                # Seach the timeline data for the music data
                if item_type == 'music':
                    if TYPE == 'volume':
                        # Get the current volume data
                        state = int(type_tag.get('volume'))
                        return state
                    elif TYPE == 'state':
                        # Get the current state data
                        state = type_tag.get('state')
                        return state
    except requests.exceptions.RequestException:
        return 'stopped'


############################################################
# Function for controlling Plexamp #########################
############################################################
def setState(CONTROL):
    action = None
    if CONTROL == 'playMedia' and PLEX_ID != '':
        # Play the (general) library radio
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
        # Get current volume and increase by specified adjustment
        current_vol = getState('volume')
        if current_vol is not None:
            volume = current_vol + VOLUME_ADJUSTEMENT
            if volume > 100:
                # If volume > 100 set it to 100
                volume = 100
            action = f'setParameters?volume={volume}'
    elif CONTROL == 'volDown':
        # Get current volume and decrease by specified adjustment
        current_vol = getState('volume')
        if current_vol is not None:
            volume = current_vol - VOLUME_ADJUSTEMENT
            if volume < 0:
                # If volume < 0 set it to 0
                volume = 0
            action = f'setParameters?volume={volume}'
    #elif CONTROL >= 1 and CONTROL <= 100:
        # Set volume to specified volume level
    #    action = f'setParameters?volume={CONTROL}'

    if action:
        try:
            # Perform the action
            requests.get(f'http://localhost:32500/player/playback/{action}')
            # Controls are used so make sure the screen is turned on
            setScreen('on')
        except requests.exceptions.RequestException:
            pass
    return


############################################################
# Function for turning the screen backlight on/off #########
############################################################
def setScreen(ACTION):
    if ACTION == 'on':
        #turn on the screen backlight
        screen.on()
    elif ACTION == 'off':
        #turn off the screen backlight
        screen.off()