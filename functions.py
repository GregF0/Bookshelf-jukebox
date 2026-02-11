#! /usr/bin/env python3
# Bookshelf jukebox functions



import requests
import settings
import xml.etree.ElementTree as ET


# Get the settings
PLEX_ID = settings.PLEX_ID
VOLUME_ADJUSTEMENT = settings.VOLUME_ADJUSTEMENT


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