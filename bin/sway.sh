#!/bin/sh
export PATH="$PATH:$HOME/.scripts/bin"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

export CARGO_HOME="$XDG_DATA_HOME"/cargo
export GOPATH="$XDG_DATA_HOME"/go

export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_DESKTOP=sway
export QT_QPA_PLATFORM=wayland
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_STYLE_OVERRIDE=kvantum

export EDITOR=nvim
export VISUAL=nvim
export SYSTEMD_EDITOR=nvim
export MANPAGER="nvim +Man!"
export PAGER="nvim -R"
exec /usr/bin/sway
