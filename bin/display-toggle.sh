#!/usr/bin/env bash

if swaymsg -t get_outputs | jq -e '.[] | select(.active == true)' >/dev/null; then
  swaymsg 'output * disable'
else
  swaymsg 'output * enable'
fi
