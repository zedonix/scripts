#!/usr/bin/env bash
set -euo pipefail

ENT='/boot/loader/entries'
FILE="$ENT/snapshot-root.conf"
SNAP_PREFIX='@snapshots'

NUM=$(snapper -c root list | awk '/timeline/ {if (match($0,/^[[:space:]]*([0-9]+)/,m)) print m[1]}' | tail -n1)

if [[ -z "$NUM" ]]; then
  printf 'error: no root snapshot found\n' >&2
  exit 1
fi

NUM=${NUM:-0}
sed -Ei "s#(@snapshots/)[0-9]+#\1${NUM}#g" /boot/loader/entries/snapshot-root.conf
printf 'root entry updated to %s/%s/snapshot\n' "$SNAP_PREFIX" "$NUM"
