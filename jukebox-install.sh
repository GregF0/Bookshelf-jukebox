#!/bin/bash

###################################
### START OF INSTALL NFC READER ###
###################################

cd ~

# Install nfc tools
sudo apt-get install -y autoconf libtool libusb-dev automake make libglib2.0-dev

# Download the source code package of libnfc
git clone https://github.com/YosoraLife/libnfc

# Write the configuration file for NFC communication
sudo mkdir -p /etc/nfc/devices.d
cd libnfc
sudo cp contrib/libnfc/pn532_spi_on_rpi.conf.sample /etc/nfc/devices.d/pn532_spi_on_rpi_3.conf

# Compile and install libnfc.
autoreconf -vis
#./configure --with-drivers=pn532_spi --sysconfdir=/etc --prefix=/usr
./configure --with-drivers=pn532_spi --sysconfdir=/etc --prefix=/usr --disable-dependency-tracking
#make
make="gmake"
sudo make install all

#################################
### END OF INSTALL NFC READER ###
#################################

#################################
### START OF INSTALL CONTROLS ###
#################################

cd ~

# Remove legacy RPi.GPIO to prevent conflicts
sudo apt remove -y python3-rpi.gpio
sudo pip uninstall -y RPi.GPIO

# Define G_AGI fallback if not present (for non-DietPi systems or if not sourced)
if ! command -v G_AGI &> /dev/null; then
    G_AGI() {
        sudo apt install -y "$@"
    }
fi

# Install control tools (Restored GUI tools: plymouth, unclutter, xterm)
# Added chromium to fix "xterm --kiosk" error (on Bookworm package is 'chromium', not 'chromium-browser')
sudo apt install -y python3 python3-spidev pip plymouth plymouth-themes jq unclutter xterm chromium

# Ensure chromium-browser command exists (legacy compatibility for DietPi scripts)
if ! command -v chromium-browser &> /dev/null && command -v chromium &> /dev/null; then
    sudo ln -s $(which chromium) /usr/bin/chromium-browser
fi

# Install python3-rpi-lgpio for Pi 5 GPIO compatibility
# This system package MUST provide the RPi.GPIO module
sudo apt install -y python3-rpi-lgpio

# Install python packages
# Use --no-deps for pn532pi to prevent it from pulling the broken RPi.GPIO from PyPI
sudo pip install --no-deps pn532pi
sudo pip install curlify requests --break-system-packages

# Download the jukebox scripts:
if [ ! -d "bookshelf-jukebox" ]; then
    git clone https://github.com/GregF0/Bookshelf-jukebox.git bookshelf-jukebox
else
    echo "Directory bookshelf-jukebox already exists. Skipping clone."
fi
cd bookshelf-jukebox

# Enable the startup script and make it start at boot:
chmod u+x jukebox-startup.sh

# Add startup script to crontab
(crontab -l; echo "@reboot /usr/bin/sh /root/bookshelf-jukebox/jukebox-startup.sh &")|awk '!x[$0]++'|crontab -

# Boot config update
# Set quiet startup screen:
if [ -f /boot/firmware/cmdline.txt ]; then
    sudo sed -i 's/console=tty1/console=tty3 splash quiet plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0/' /boot/firmware/cmdline.txt
else
    sudo sed -i 's/console=tty1/console=tty3 splash quiet plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0/' /boot/cmdline.txt
fi

# Set plymouth startup theme
sudo plymouth-set-default-theme -R spinner

# Set plymouth watermark
sudo cp ~/bookshelf-jukebox/plexamp-splash.png /usr/share/plymouth/themes/spinner/watermark.png

# Hide mouse
G_AGI unclutter && echo '/usr/bin/unclutter -idle 0.1 &' > /etc/chromium.d/dietpi-unclutter

###############################
### END OF INSTALL CONTROLS ###
###############################

################################
### START OF INSTALL PLEXAMP ###
################################

cd ~

# Install NodeJS
sudo apt-get install -y ca-certificates curl bzip2 gnupg && sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
NODE_MAJOR=20
echo deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update && sudo apt-get install -y nodejs

# Install Plexamp
curl https://plexamp.plex.tv/headless/Plexamp-Linux-headless-v4.12.4.tar.bz2 > plexamp.tar.bz2
tar -xvf plexamp.tar.bz2

# Start Plexamp for the first time in background to allow configuration
echo "Starting Plexamp initialization..."
echo "Please wait a moment, then visit http://<YOUR_PI_IP>:32500 in your browser."
echo "Claim your player, then come back here."
node plexamp/js/index.js > plexamp_init.log 2>&1 &
PLEX_PID=$!

# Wait for user to confirm they have claimed the player
echo ""
read -p "Press ENTER once you have successfully claimed the player in the browser..."

# Stop the temporary Plexamp process so we can install it as a service
echo "Stopping temporary Plexamp process..."
kill $PLEX_PID
sleep 5

# Change username
sudo sed -i 's/pi/root/' plexamp/plexamp.service

# Change root user location
sudo sed -i 's/\/home\//\//' plexamp/plexamp.service

# Enable the startup script and start Plexamp:
sudo cp plexamp/plexamp.service /lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable plexamp
sudo systemctl start plexamp

##############################
### END OF INSTALL PLEXAMP ###
##############################
