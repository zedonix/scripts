#!/bin/sh
if swaymsg -t get_outputs | grep -q '"active": true'; then
  swaymsg 'output * disable'
else
  swaymsg 'output * enable'
fi
