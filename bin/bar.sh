#!/bin/bash
while true; do
    timestamp=$(date +'%A, %d %b | %I:%M %p')

    bat_capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "N/A")
    bat_status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)

    [ "$bat_status" = "Charging" ] && status="⚡" || status=""

    echo "[$timestamp | Battery: ${bat_capacity}%$status]"
    sleep 60
done
