#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <package-name|aur-git-url>"
    exit 1
fi

input="$1"
aur_dir="$HOME/.aur"

mkdir -p "$aur_dir"
cd "$aur_dir" || { echo "Failed to access $aur_dir"; exit 1; }

# Detect if input is a URL or a package name
if [[ "$input" =~ ^https://aur\.archlinux\.org/([a-zA-Z0-9._-]+)\.git$ ]]; then
    pkg="${BASH_REMATCH[1]}"
    url="$input"
else
    pkg="$input"
    url="https://aur.archlinux.org/$pkg.git"
fi

echo "Cloning from: $url"

if git clone "$url"; then
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
    echo "Failed to clone $pkg. Is '$pkg' a valid package or URL?"
fi
