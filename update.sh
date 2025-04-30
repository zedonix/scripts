#!/bin/bash

aur_dir="$HOME/.aur"
cd "$aur_dir"

for pkg_dir in */ ; do
    cd "$pkg_dir" || continue
    output=$(git pull 2>&1)
    if [[ "$output" == *"Already up to date."* ]]; then
        echo "No updates for $pkg_dir"
    else
        less PKGBUILD
        read -p "Build $pkg? [Y/n] " -r
        if [[ $REPLY =~ ^[Yy]?$ ]]; then
            makepkg -si --noconfirm --needed
        fi
    fi
    cd ..
done
