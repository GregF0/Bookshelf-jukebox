#!/bin/bash

# Resolve directory of this script
#DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

sleep 15
/usr/bin/python3 "/root/bookshelf-jukebox/controls.py" &
/usr/bin/python3 "/root/bookshelf-jukebox/nfc_reader.py" &