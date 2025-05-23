#!/bin/bash
set -euo pipefail

PACMAN_CONF="/etc/pacman.conf"
CUSTOM_REPO_DIR="/home/custompkgs"
AURUTILS_DIR="$HOME/.aurutils"

# Backup pacman.conf
sudo cp "$PACMAN_CONF" "${PACMAN_CONF}.bak.$(date +%F-%T)"

# Uncomment custom repo lines
sudo sed -i '/^#\[custom\]/s/^#//' "$PACMAN_CONF"
sudo sed -i '/^#SigLevel = Optional TrustAll/s/^#//' "$PACMAN_CONF"
sudo sed -i '/^#Server = file:\/\/\/home\/custompkgs/s/^#//' "$PACMAN_CONF"

# Create custom repo directory
sudo install -d "$CUSTOM_REPO_DIR" -o "$USER" -m 755

# Initialize repo database
sudo repo-add "$CUSTOM_REPO_DIR/custom.db.tar"

# Refresh pacman database
sudo pacman -Sy

# Setup aurutils directory
mkdir -p "$AURUTILS_DIR"
cd "$AURUTILS_DIR"

# Clone aurutils if not present
if [ ! -d "aurutils" ]; then
    git clone https://aur.archlinux.org/aurutils.git
fi

cd aurutils

# Build and install aurutils
makepkg -si

# paru -S sway-audio-idle-inhibit-git sdl-ball snake tlpui
#ollama pull gemma3:1b
