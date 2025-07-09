#!/bin/bash
while true; do
    timestamp=$(date +"%a %d/%m %H:%M")

    bat_capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "N/A")
    bat_status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)

    [ "$bat_status" = "Charging" ] && status="⚡" || status=""

    echo "[$timestamp | Battery: ${bat_capacity}%$status]"
    sleep 1
done
