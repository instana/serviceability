#!/bin/bash


# Prompt user for the location of the meta-0.8.2.pax.Z file
echo "Enter the location of meta-0.8.2.pax.Z file:  PAX_FILE_LOCATION"
read PAX_FILE_LOCATION

# Define Installation directory for z/OS
Installation_DIR_ZOS="${PWD}/zopen"

# Function to check if a command is available
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Function to configure setup
configure_setup() {
    if [ ! -f "$PAX_FILE_LOCATION" ]; then
        echo "The provided pax file '$PAX_FILE_LOCATION' does not exist. Please check the path."
        exit 1
    fi

    echo "Extracting $PAX_FILE_LOCATION..."
    pax -rf "$PAX_FILE_LOCATION"

    mkdir -p "$Installation_DIR_ZOS"
    echo $Installation_DIR_ZOS
    cd meta-main && . ./.env

    echo "Initializing zopen in directory $Installation_DIR_ZOS..."
    zopen init "$Installation_DIR_ZOS" -y

    . "${Installation_DIR_ZOS}/etc/zopen-config"
}

# Function to check User Privilege
check_user_privilege() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "You are root!"
  else
    echo "You are not root Aborting Agent Installation. Switch to the user which has root privilege and retry"
    exit 1
  fi
}

# Function to install missing packages
install_package() {
    echo "Installing $1..."
    zopen install "$1"
    # Check if the installation was successful
    if check_command "$1"; then
        echo "$1 installed successfully."
    else
        echo "Failed to install $1. Please check the logs and try again."
        exit 1
    fi
}


# Check if user is with required privilege
check_user_privilege

# Check if pax is available and configure setup if it's found
if ! check_command "pax"; then
    echo "pax not found. Please ensure pax is installed on your system. Aborting..."
    exit 1
else
    echo "pax is already installed."
    configure_setup
fi

# Check and install sed and gzip if missing
for package in "sed" "gzip" "curl" "bash"; do
    if ! check_command "$package"; then
        echo "$package not found, attempting to install..."
        install_package "$package"
    else
        echo "$package is already installed."
    fi
done

echo "Script completed."
