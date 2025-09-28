#!/usr/bin/env bash
set -euo pipefail

ENT='/boot/loader/entries'
FILE="$ENT/snapshot-root.conf"
SNAP_PREFIX='@snapshots'

NUM="$(snapper -c root list | awk -F'|' 'NR>2 && /timeline/ {gsub(/^ +| +$/,"",$1); last=$1} END{print last}')"

if [[ -z "$NUM" ]]; then
  printf 'error: no root snapshot found\n' >&2
  exit 1
fi

cp -- "$FILE" "$FILE.bak"
sed -i -E "s#(rootflags=subvol=${SNAP_PREFIX}/)[0-9]+(/snapshot)#\1${NUM}\2#g" "$FILE"
printf 'root entry updated to %s/%s/snapshot\n' "$SNAP_PREFIX" "$NUM"
