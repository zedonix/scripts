#!/usr/bin/env bash
SNAP="/.snapshots"
ENT="/boot/loader/entries"

latest() {
    snapper -c "$1" list | awk -F'|' -v t="$2" 'NR>2 && /timeline/ {
    gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$3);
    split($3,d," "); k=(t=="daily"?d[1]:substr(d[1],1,7));
    if(epoch[k]==""||epoch[k]<mktime(gensub(/[-:]/," ","g",d[1]" "d[2]))){
        epoch[k]=mktime(gensub(/[-:]/," ","g",d[1]" "d[2]));snap[k]=$1;
    }
} END{max="";for(k in snap)if(k>max){max=k;n=snap[k];}print snap[k]}'
}

update() {
    cp "$1" "$1.bak"
    sed -i -E "s#subvol=[^ ,]+#subvol=$2#g;/^options /{s/$/ rootflags=subvol=$2/}" "$1"
}

update "$ENT/snap-root-latest.conf" "$SNAP/$(latest root daily)/snapshot"
update "$ENT/snap-root-monthly.conf" "$SNAP/$(latest root monthly)/snapshot"
update "$ENT/snap-home-latest.conf" "$SNAP/$(latest home daily)/snapshot"
update "$ENT/snap-home-monthly.conf" "$SNAP/$(latest home monthly)/snapshot"

echo "Updated boot entries."
