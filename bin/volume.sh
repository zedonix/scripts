#!/usr/bin/env bash

# Script to create pop-up notification when volume changes using wpctl

# Small delay to allow volume change to register
sleep 0.05

# Get the current volume as an integer percentage
VOLUME=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d\n", $2 * 100}')

# Get mute state: 1 if muted, 0 if not muted
IS_MUTE=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && echo 1 || echo 0)

# Choose icon based on mute state and volume
if [[ "$IS_MUTE" == "0" ]]; then
    notify-send.sh "Volume: $VOLUME%" \
        --replace-file=/tmp/audio-notification \
        -t 2000 \
        -h int:value:"$VOLUME" \
        -h string:synchronous:volume-change
else
    notify-send.sh "Muted (volume: $VOLUME%)" \
        --replace-file=/tmp/audio-notification \
        -t 2000 \
        -h int:value:"$VOLUME" \
        -h string:synchronous:volume-change
fi
