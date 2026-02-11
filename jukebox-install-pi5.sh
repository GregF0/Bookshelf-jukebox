#!/bin/bash

# Bookshelf Jukebox Installer for Raspberry Pi 5 (DietPi / Bookworm)
# SIMPLIFIED: Installs directly to system (no venv)

set -e

echo "Starting installation for Raspberry Pi 5 / DietPi..."

###################################
### START OF INSTALL NFC READER ###
###################################

cd ~

# Install build dependencies
echo "Installing build dependencies..."
sudo apt-get update
# Added python3-pip and libnfc dependencies
sudo apt-get install -y autoconf libtool libusb-dev automake make libglib2.0-dev git python3-pip

# Download libnfc source
if [ ! -d "libnfc" ]; then
    echo "Cloning libnfc..."
    git clone https://github.com/YosoraLife/libnfc
else
    cd libnfc
    git pull
    cd ..
fi

# Configure NFC
echo "Configuring NFC..."
# Enable SPI on Pi 5 (Bookworm)
CONFIG_FILE="/boot/firmware/config.txt"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="/boot/config.txt"
fi
if ! grep -q "dtparam=spi=on" "$CONFIG_FILE"; then
    echo "dtparam=spi=on" | sudo tee -a "$CONFIG_FILE"
fi

sudo mkdir -p /etc/nfc/devices.d
cd libnfc

# Use the sample config
if [ -f "contrib/libnfc/pn532_spi_on_rpi.conf.sample" ]; then
    sudo cp -n contrib/libnfc/pn532_spi_on_rpi.conf.sample /etc/nfc/devices.d/pn532_spi_on_rpi.conf || true
fi

# Compile and install libnfc
echo "Compiling libnfc..."
if [ ! -f "config.h" ]; then
    autoreconf -vis
    ./configure --with-drivers=pn532_spi --sysconfdir=/etc --prefix=/usr --disable-dependency-tracking
fi
make
sudo make install all

#################################
### END OF INSTALL NFC READER ###
#################################

#################################
### START OF INSTALL CONTROLS ###
#################################

cd ~

# Install system dependencies
# Installing python packages via apt where available for system stability
echo "Installing Python system packages..."
sudo apt install -y python3-spidev python3-requests python3-gpiozero python3-lgpio plymouth plymouth-themes jq unclutter

# Install remaining python packages via PIP globally
# --break-system-packages is required on Bookworm to install outside venv/apt
echo "Installing PIP packages globally..."
sudo pip3 install pn532pi curlify --break-system-packages

# Download/Update jukebox scripts
if [ ! -d "bookshelf-jukebox" ]; then
    git clone https://github.com/GregF0/bookshelf-jukebox.git
    cd bookshelf-jukebox
else
    cd bookshelf-jukebox
    git pull
fi

# Make scripts executable
chmod u+x jukebox-startup.sh
chmod u+x jukebox-install-pi5.sh

# Add startup script to crontab
# Using the original jukebox-startup.sh directly since we are using system python
(crontab -l 2>/dev/null; echo "@reboot /usr/bin/bash $HOME/bookshelf-jukebox/jukebox-startup.sh &") | awk '!x[$0]++' | crontab -

# Setup Plymouth (Splash Screen)
# Note: /boot/cmdline.txt moved to /boot/firmware/cmdline.txt in Bookworm/Pi 5
CMDLINE_FILE="/boot/firmware/cmdline.txt"
if [ ! -f "$CMDLINE_FILE" ]; then
    CMDLINE_FILE="/boot/cmdline.txt"
fi

echo "Configuring boot splash using $CMDLINE_FILE..."
if grep -q "console=tty1" "$CMDLINE_FILE"; then
    sudo sed -i 's/console=tty1/console=tty3 splash quiet plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0/' "$CMDLINE_FILE"
fi

sudo plymouth-set-default-theme -R spinner
SPLASH_IMG="$HOME/bookshelf-jukebox/plexamp-splash.png"
if [ -f "$SPLASH_IMG" ]; then
    sudo cp "$SPLASH_IMG" /usr/share/plymouth/themes/spinner/watermark.png
fi

# Hide mouse for DietPi
if command -v unclutter &> /dev/null; then
    echo '/usr/bin/unclutter -idle 0.1 &' | sudo tee /etc/chromium.d/dietpi-unclutter > /dev/null
fi

###############################
### END OF INSTALL CONTROLS ###
###############################

################################
### START OF INSTALL PLEXAMP ###
################################

cd ~

# Install NodeJS 20
echo "Installing Node.js..."
sudo apt-get install -y ca-certificates curl gnupg
if [ ! -f "/etc/apt/keyrings/nodesource.gpg" ]; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
fi
NODE_MAJOR=20
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update && sudo apt-get install -y nodejs

# Install Plexamp
echo "Installing Plexamp..."
if [ ! -d "plexamp" ]; then
    curl -L https://plexamp.plex.tv/headless/Plexamp-Linux-headless-v4.12.4.tar.bz2 > plexamp.tar.bz2
    tar -xvf plexamp.tar.bz2
fi

# Setup Plexamp Service
cd plexamp
SERVICE_FILE="plexamp.service"
if [ -f "$SERVICE_FILE" ]; then
    # Create service for CURRENT user (DietPi usually runs as root or dietpi)
    # Original script used 'root' mostly.
    CURRENT_USER=$(whoami)
    sudo sed -i "s/User=pi/User=$CURRENT_USER/g" "$SERVICE_FILE"
    sudo sed -i "s|/home/pi|$HOME|g" "$SERVICE_FILE"
    
    sudo cp "$SERVICE_FILE" /lib/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable plexamp
    
    echo "Plexamp installed. Please run 'node plexamp/js/index.js' manually to claim the player."
else
    echo "Warning: $SERVICE_FILE not found."
fi

echo "Installation complete!"
echo "Please restart manually after claiming Plexamp."
