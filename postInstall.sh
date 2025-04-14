#!/bin/bash

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
# sudo pacman -S gnome-themes-extra

# Snapper setup
sudo umount /.snapshots
sudo rm -rf
sudo snapper -c root create-config /
sudo nvim /etc/snapper/config/root
sudo chmod a+rx /.snapshots/
sudo systemctl start snapper-timeline.timer
sudo systemctl enable snapper-timeline.timer
sudo systemctl start snapper-cleanup.timer
sudo systemctl enable snapper-cleanup.timer
sudo systemctl start grup-btrfs.path
sudo systemctl enable grup-btrfs.path

# aur installation
aur_pkgs=(
    ungoogled-chromium-bin
    chromium-extension-web-store
    chromium-extension-ublock-origin
    sway-audio-idle-inhibit-git
    shotman
    onlyoffice-bin
    github-cli-git
)

mkdir -p ../aur
cd ../aur

for pkg in "${aur_pkgs[@]}"; do
    git clone "https://aur.archlinux.org/$pkg.git"
    cd "$pkg"
    cat PKGBUILD
    read -p "Wanna build $pkg? (y/n) " choice
    if [ "$choice" == "y" ]; then
        makepkg -si
    fi
    cd ..
done
