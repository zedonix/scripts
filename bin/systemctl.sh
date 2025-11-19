#!/usr/bin/env bash

choice=$(printf "Lock\nReboot\nPoweroff\nExit Sway\n" | fuzzel --dmenu --prompt "Systemctl > ")

case "$choice" in
"Reboot")
  confirm=$(printf "No\nYes" | fuzzel --dmenu --prompt "Confirm reboot? ")
  [ "$confirm" = "Yes" ] && systemctl reboot
  ;;
"Poweroff")
  confirm=$(printf "No\nYes" | fuzzel --dmenu --prompt "Confirm poweroff? ")
  [ "$confirm" = "Yes" ] && systemctl poweroff
  ;;
"Exit Sway")
  confirm=$(printf "No\nYes" | fuzzel --dmenu --prompt "Confirm exit sway? ")
  [ "$confirm" = "Yes" ] && swaymsg exit
  ;;
"Lock")
  swaylock --ignore-empty-password --show-failed-attempts -fFec 282828
  ;;
esac
