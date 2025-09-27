#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT_BASE="/.snapshots"
BOOT_ENTRIES_DIR="/boot/loader/entries"

update_entry() {
    local file="$1" subvol="$2"
    cp "$file" "$file.bak"
    sed -i -E "s#subvol=[^ ,]+#subvol=${subvol}#g; t; /^options /s#$# rootflags=subvol=${subvol}#; t; /^options /a options rootflags=subvol=${subvol}" "$file"
}

latest_snapshot() {
    local cfg="$1" type="$2"
    snapper -c "$cfg" list | awk -F'|' -v type="$type" '
    NR>2 && /timeline/ {
        gsub(/^ +| +$/,"",$1);
        gsub(/^ +| +$/,"",$3);
        gsub(/^ +| +$/,"",$5);
        gsub(/^ +| +$/,"",$6);
        split($3, dt, " ");
        if (type=="daily") key=dt[1];
        else if (type=="monthly") key=substr(dt[1],1,7);
        if (epoch[key]=="" || epoch[key]<mktime(gensub(/[-:]/," ","g",dt[1]" "dt[2]))) {
            epoch[key]=mktime(gensub(/[-:]/," ","g",dt[1]" "dt[2]));
            snap[key]=$1;
        }
    }
    END {
        max="";
        for (k in snap) if (k>max) { max=k; num=snap[k]; }
        print num;
    }'
}

ROOT_DAILY=$(latest_snapshot root daily)
ROOT_MONTHLY=$(latest_snapshot root monthly)
HOME_DAILY=$(latest_snapshot home daily)
HOME_MONTHLY=$(latest_snapshot home monthly)

update_entry "$BOOT_ENTRIES_DIR/snap-root-latest.conf" "$SNAPSHOT_BASE/$ROOT_DAILY/snapshot"
update_entry "$BOOT_ENTRIES_DIR/snap-root-monthly.conf" "$SNAPSHOT_BASE/$ROOT_MONTHLY/snapshot"
update_entry "$BOOT_ENTRIES_DIR/snap-home-latest.conf" "$SNAPSHOT_BASE/$HOME_DAILY/snapshot"
update_entry "$BOOT_ENTRIES_DIR/snap-home-monthly.conf" "$SNAPSHOT_BASE/$HOME_MONTHLY/snapshot"

echo "Boot entries updated."
