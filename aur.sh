#!/bin/bash

aur_pkgs=(
    sway-audio-idle-inhibit-git
    swayosd-git
    github-cli-git
)

aur_dir="$HOME/.aur"
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
