#!/bin/bash

# Resolve directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

sleep 15
/usr/bin/python3 "$DIR/controls.py" &
/usr/bin/python3 "$DIR/nfc_reader.py" &
/usr/bin/python3 "$DIR/screen.py" &