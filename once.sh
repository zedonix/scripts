#!/bin/bash

MARKER="$HOME/.config/.run_sh_done"

if [ ! -f "$MARKER" ]; then
  bash ~/.scripts/run.sh && touch "$MARKER"
fi
