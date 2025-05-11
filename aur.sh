#!/bin/bash

aur_dir="$HOME/.paru"
mkdir -p "$aur_dir"
cd "$aur_dir"

git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si

paru -S sway-audio-idle-inhibit-git sdl-ball

# Remove passwordless after running run.sh
echo "Removing temporary passwordless sudo rule..."
sudo rm -f /etc/sudoers.d/010_$(whoami)-nopasswd
