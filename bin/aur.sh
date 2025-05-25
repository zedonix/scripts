#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <package-name>"
    exit 1
fi

pkg="$1"
aur_dir="$HOME/.aur"

mkdir -p "$aur_dir"
cd "$aur_dir" || { echo "Failed to access $aur_dir"; exit 1; }

if git clone "https://aur.archlinux.org/$pkg.git"; then
    cd "$pkg" || { echo "Failed to enter $pkg directory"; exit 1; }
    if [ ! -f PKGBUILD ]; then
        echo "Error: Package '$pkg' does not exist on the AUR."
        cd ..
        rm -rf "$pkg"
        exit 1
    fi
    less PKGBUILD
    read -p "Build $pkg? [Y/n] " -r
    if [[ $REPLY =~ ^[Yy]?$ ]]; then
        if makepkg -si --noconfirm --needed; then
            echo "$pkg is installed"
        else
            echo "Build failed. Opening package page in browser..."
            firefox "https://aur.archlinux.org/packages/$pkg"
        fi
    else
        echo "Build cancelled."
    fi
else
    echo "Failed to clone $pkg. Is '$pkg' a valid package?"
fi
