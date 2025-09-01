#!/usr/bin/env bash
set -euo pipefail

chooser=(fuzzel --dmenu)
selected="$(cat - | "${chooser[@]}")" || exit 1

printf '%s\n' "$selected"
