#!/bin/bash

aur_dir="$HOME/.paru"
mkdir -p "$aur_dir"
cd "$aur_dir"

git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si

paru -S ungoogled-chromium-bin chromium-extension-return-youtube-dislike chromium-extension-ublock-origin sway-audio-idle-inhibit sdl-ball
