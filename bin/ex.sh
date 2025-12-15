#!/usr/bin/env bash
set -euo pipefail

file="${1:-}"

[[ -f "$file" ]] || {
    echo "Invalid file"
    exit 1
}

strip_ext() {
    local n="$1"
    for e in \
        .tar.bz2 .tar.gz .tar.xz .tar.zst .tbz2 .tgz \
        .tar .zip .rar .7z; do
        [[ $n == *$e ]] && {
            echo "${n%"$e"}"
            return
        }
    done
    echo "${n%.*}"
}

base="$(strip_ext "$(basename "$file")")"
dest="."

needs_dir=false

# ---------- PRECHECK ----------
case "$file" in
*.tar.* | *.tar)
    top=$(tar -tf "$file" | awk -F/ '{print $1}' | sort -u)
    [[ $(echo "$top" | wc -l) -ne 1 ]] && needs_dir=true
    ;;
*.zip)
    top=$(unzip -Z1 "$file" | awk -F/ '{print $1}' | sort -u)
    [[ $(echo "$top" | wc -l) -ne 1 ]] && needs_dir=true
    ;;
*.7z)
    top=$(7z l "$file" | awk '/^D|^-/ {print $6}' | awk -F/ '{print $1}' | sort -u)
    [[ $(echo "$top" | wc -l) -ne 1 ]] && needs_dir=true
    ;;
*.rar)
    top=$(unrar lb "$file" | awk -F/ '{print $1}' | sort -u)
    [[ $(echo "$top" | wc -l) -ne 1 ]] && needs_dir=true
    ;;
*)
    # Single-file compressors cannot be inspected
    needs_dir=true
    ;;
esac

if $needs_dir; then
    dest="$base"
    mkdir -p "$dest"
fi

# ---------- EXTRACT ONCE ----------
case "$file" in
*.tar.bz2 | *.tbz2) tar xjf "$file" -C "$dest" ;;
*.tar.gz | *.tgz) tar xzf "$file" -C "$dest" ;;
*.tar.xz) tar xf "$file" -C "$dest" ;;
*.tar.zst) tar --use-compress-program=unzstd -xvf "$file" -C "$dest" ;;
*.tar) tar xf "$file" -C "$dest" ;;
*.zip) unzip "$file" -d "$dest" ;;
*.7z) 7z x "$file" -o"$dest" ;;
*.rar) unrar x "$file" "$dest" ;;
*.gz) gunzip -c "$file" >"$dest/${base}" ;;
*.bz2) bunzip2 -c "$file" >"$dest/${base}" ;;
*.xz) unxz -c "$file" >"$dest/${base}" ;;
*)
    echo "Unsupported archive"
    exit 2
    ;;
esac
