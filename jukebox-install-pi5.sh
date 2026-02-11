#!/bin/bash

# Bookshelf Jukebox Installer for Raspberry Pi 5 (Bookworm)

set -e

echo "Starting installation for Raspberry Pi 5 / Bookworm..."

###################################
### START OF INSTALL NFC READER ###
###################################

cd ~

# Install build dependencies
echo "Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y autoconf libtool libusb-dev automake make libglib2.0-dev git python3-venv python3-full python3-pip

# Download libnfc source
if [ ! -d "libnfc" ]; then
    echo "Cloning libnfc..."
    git clone https://github.com/YosoraLife/libnfc
else
    # Pull latest if exists
    cd libnfc
    git pull
    cd ..
fi

# Configure NFC
echo "Configuring NFC..."
sudo mkdir -p /etc/nfc/devices.d
cd libnfc # Ensure we are in libnfc dir

# Use the sample config, renaming provided sample if needed
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
sudo apt install -y python3-spidev plymouth plymouth-themes jq unclutter

# Setup Python Virtual Environment (PEP 668 compliance)
echo "Setting up Python Virtual Environment..."
VENV_DIR="$HOME/bookshelf-jukebox/venv"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi

# Activate venv for installation
source "$VENV_DIR/bin/activate"

# Install Python dependencies in venv
echo "Installing Python dependencies in venv..."
pip install --upgrade pip
pip install gpiozero lgpio rpi-lgpio  # gpiozero with lgpio backend for Pi 5
pip install pn532pi curlify requests

# Download/Update jukebox scripts
if [ ! -d "bookshelf-jukebox" ]; then
    git clone https://github.com/YosoraLife/bookshelf-jukebox.git
    cd bookshelf-jukebox
else
    cd bookshelf-jukebox
    git pull
fi

# Make scripts executable
chmod u+x jukebox-startup.sh
chmod u+x jukebox-install-pi5.sh

# Update startup script path in crontab - using wrapper
echo "Creating venv-aware startup wrapper..."
WRAPPER_SCRIPT="$HOME/bookshelf-jukebox/jukebox-startup-venv.sh"
cat <<EOF > "$WRAPPER_SCRIPT"
#!/bin/bash
source $VENV_DIR/bin/activate
# Run components in background
python $HOME/bookshelf-jukebox/controls.py &
python $HOME/bookshelf-jukebox/nfc_reader.py &
python $HOME/bookshelf-jukebox/screen.py &
EOF
chmod +x "$WRAPPER_SCRIPT"

# Add to crontab if not exists
(crontab -l 2>/dev/null; echo "@reboot $WRAPPER_SCRIPT") | awk '!x[$0]++' | crontab -

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

# Hide mouse
if command -v unclutter &> /dev/null; then
    # Create autostart for openbox/lxde/etc if X11
    # For now, just placing legacy config
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
# Ensure service file exists
SERVICE_FILE="plexamp.service"
if [ -f "$SERVICE_FILE" ]; then
    # Use appropriate user
    CURRENT_USER=$(whoami)
    sudo sed -i "s/User=pi/User=$CURRENT_USER/g" "$SERVICE_FILE"
    # Fix home path: /home/pi -> /home/$USER
    sudo sed -i "s|/home/pi|$HOME|g" "$SERVICE_FILE"
    
    sudo cp "$SERVICE_FILE" /lib/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable plexamp
    # Don't start automatically to allow claiming
    echo "Plexamp installed. Please run 'node plexamp/js/index.js' manually to claim the player."
else
    echo "Warning: $SERVICE_FILE not found."
fi

echo "Installation complete!"
echo "Please restart manually after claiming Plexamp."
