#!/bin/bash

aur_dir="$HOME/.paru"
mkdir -p "$aur_dir"
cd "$aur_dir"

git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si

paru -S sway-audio-idle-inhibit-git sdl-ball auto-cpufreq
sudo systemctl enable --now auto-cpufreq.service
ollama pull gemma3:1b
