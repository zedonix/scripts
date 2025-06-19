#!/bin/sh

export PATH="$PATH:$HOME/.scripts/bin"

export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_DESKTOP=sway
export QT_QPA_PLATFORM=wayland
export QT_STYLE_OVERRIDE=kvantum

exec /usr/bin/sway
