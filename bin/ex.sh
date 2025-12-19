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
    mapfile -t tops <<<"$top"
    [[ ${#tops[@]} -ne 1 ]] && needs_dir=true
    ;;
*.zip)
    top=$(unzip -Z1 "$file" | awk -F/ '{print $1}' | sort -u)
    mapfile -t tops <<<"$top"
    [[ ${#tops[@]} -ne 1 ]] && needs_dir=true
    ;;
*.7z)
    top=$(7z l -ba "$file" | awk -F/ '{print $1}' | sort -u)
    mapfile -t tops <<<"$top"
    [[ ${#tops[@]} -ne 1 ]] && needs_dir=true
    ;;
*.rar)
    top=$(unrar lb "$file" | awk -F/ '{print $1}' | sort -u)
    mapfile -t tops <<<"$top"
    [[ ${#tops[@]} -ne 1 ]] && needs_dir=true
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

# ---------- EXTRACT ONCE (HARDENED) ----------
tar_safe_flags=(
    --no-same-owner
    --no-same-permissions
    --delay-directory-restore
)

case "$file" in
*.tar.bz2 | *.tbz2)
    tar xjvf "$file" -C "$dest" "${tar_safe_flags[@]}"
    ;;
*.tar.gz | *.tgz)
    tar xzvf "$file" -C "$dest" "${tar_safe_flags[@]}"
    ;;
*.tar.xz)
    tar xvf "$file" -C "$dest" "${tar_safe_flags[@]}"
    ;;
*.tar.zst)
    tar --zstd -xvf "$file" -C "$dest" "${tar_safe_flags[@]}"
    ;;
*.tar)
    tar xvf "$file" -C "$dest" "${tar_safe_flags[@]}"
    ;;
*.zip)
    unzip -v "$file" -d "$dest"
    ;;
*.7z)
    7z x "$file" -o"$dest" -bb1
    ;;
*.rar)
    unrar x -v "$file" "$dest"
    ;;
*.gz)
    gunzip -v -c "$file" >"$dest/$base"
    ;;
*.bz2)
    bunzip2 -v -c "$file" >"$dest/$base"
    ;;
*.xz)
    unxz -v -c "$file" >"$dest/$base"
    ;;
*)
    echo "Unsupported archive"
    exit 2
    ;;
esac
