#!/bin/bash

set -e

# ufw setup
sudo ufw limit 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo systemctl enable ufw

# GTK setup
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# aur installation
aur_pkgs=(
    ungoogled-chromium-bin
    chromium-extension-web-store
    chromium-extension-ublock-origin
    github-cli-git
    btrfs-assistant
    sway-audio-idle-inhibit-git
    shotman
    swayosd-git
    onlyoffice-bin
)

aur_dir="$HOME/aur"
mkdir -p "$aur_dir"
cd "$aur_dir"

for pkg in "${aur_pkgs[@]}"; do
    read -p "Install $pkg? [Y/n] " -r
    if [[ $REPLY =~ ^[Yy]?$ ]]; then
        git clone "https://aur.archlinux.org/$pkg.git"
        cd "$pkg"
        less PKGBUILD
        read -p "Build $pkg? [Y/n] " -r
        if [[ $REPLY =~ ^[Yy]?$ ]]; then
            makepkg -si --noconfirm --needed
        fi
        cd ..
    fi
done
