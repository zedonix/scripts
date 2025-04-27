#!/bin/bash

aur_pkgs=(
    ungoogled-chromium-bin
    chromium-extension-web-store
    chromium-extension-ublock-origin
    chromium-extension-return-youtube-dislike
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
