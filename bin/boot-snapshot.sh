#!/usr/bin/env bash
set -euo pipefail

SNAP_PREFIX='@snapshots'
ENT='/boot/loader/entries'

latest() {
    snapper -c "$1" list | awk -F'|' -v t="$2" 'NR>2 && /timeline/ {
    gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$3);
    split($3,d," "); k=(t=="daily"?d[1]:substr(d[1],1,7));
    if(epoch[k]==""||epoch[k]<mktime(gensub(/[-:]/," ","g",d[1]" "d[2]))){
      epoch[k]=mktime(gensub(/[-:]/," ","g",d[1]" "d[2])); snap[k]=$1;
    }
  } END { max=""; for(k in snap) if(k>max){ max=k; n=snap[k]; } print snap[k] }'
}

update() {
    local file="$1"
    local num="$2"
    cp -- "$file" "$file.bak"
    sed -i -E "s#(rootflags=subvol=${SNAP_PREFIX}/)[0-9]+(/snapshot)#\1${num}\2#g" "$file"
}

root_num="$(latest root daily)"
home_num="$(latest home daily)"

if [[ -z "$root_num" || -z "$home_num" ]]; then
    printf 'error: could not determine latest snapshot id(s). root="%s" home="%s"\n' "$root_num" "$home_num" >&2
    exit 1
fi

update "$ENT/snapshot-root.conf" "$root_num"
update "$ENT/snapshot-home.conf" "$home_num"

printf 'Updated boot entries to %s/%s/snapshot and %s/%s/snapshot\n' \
    "$SNAP_PREFIX" "$root_num" "$SNAP_PREFIX" "$home_num"
