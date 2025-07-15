#!/bin/sh

# Send a notification if the laptop battery is either low or is fully charged.

export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

# Battery percentage levels
WARNING_LEVEL=20
CRITICAL_LEVEL=5
BATTERY_DISCHARGING=$(acpi -b | grep "Battery 0" | grep -c "Discharging")
BATTERY_LEVEL=$(acpi -b | grep "Battery 0" | grep -P -o '[0-9]+(?=%)')

# Notification state files
FULL_FILE=/tmp/batteryfull
EMPTY_FILE=/tmp/batteryempty
CRITICAL_FILE=/tmp/batterycritical

# Reset state on change of power mode
if [ "$BATTERY_DISCHARGING" -eq 1 ] && [ -f "$FULL_FILE" ]; then
    rm "$FULL_FILE"
elif [ "$BATTERY_DISCHARGING" -eq 0 ] && [ -f "$EMPTY_FILE" ]; then
    rm "$EMPTY_FILE"
fi

# Icon paths (adjust if you're not using Papirus)
ICON_FULL="/usr/share/icons/Papirus/48x48/status/battery-full.svg"
ICON_LOW="/usr/share/icons/Papirus/48x48/status/battery-low.svg"
ICON_CRITICAL="/usr/share/icons/Papirus/48x48/status/battery-caution.svg"

# Notification logic
if [ "$BATTERY_LEVEL" -gt 99 ] && [ "$BATTERY_DISCHARGING" -eq 0 ] && [ ! -f "$FULL_FILE" ]; then
    notify-send "Battery Charged" "Battery is fully charged." -i "$ICON_FULL" -r 9991
    touch "$FULL_FILE"

elif [ "$BATTERY_LEVEL" -le "$WARNING_LEVEL" ] && [ "$BATTERY_DISCHARGING" -eq 1 ] && [ ! -f "$EMPTY_FILE" ]; then
    notify-send "Low Battery" "${BATTERY_LEVEL}% of battery remaining." -u critical -i "$ICON_LOW" -r 9991
    touch "$EMPTY_FILE"

elif [ "$BATTERY_LEVEL" -le "$CRITICAL_LEVEL" ] && [ "$BATTERY_DISCHARGING" -eq 1 ] && [ ! -f "$CRITICAL_FILE" ]; then
    notify-send "Battery Critical" "The computer will shutdown soon." -u critical -i "$ICON_CRITICAL" -r 9991
    touch "$CRITICAL_FILE"
fi
