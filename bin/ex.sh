#!/bin/bash

file="$1"
if [[ -f "$file" ]]; then
    case "$file" in
        *.tar.bz2) tar xjf "$file" ;;
        *.tar.gz) tar xzf "$file" ;;
        *.tar.xz) tar xf "$file" ;;
        *.tar.zst) tar --use-compress-program=unzstd -xvf "$file" ;;
        *.xz) unxz "$file" ;;
        *.bz2) bunzip2 "$file" ;;
        *.rar) unrar x "$file" ;;
        *.gz) gunzip "$file" ;;
        *.tar) tar xf "$file" ;;
        *.tbz2) tar xjf "$file" ;;
        *.tgz) tar xzf "$file" ;;
        *.zip) unzip "$file" ;;
        *.Z) uncompress "$file" ;;
        *.7z) 7z x "$file" ;;
        *) echo "'$file' cannot be extracted automatically." ;;
    esac
else
    echo "'$file' is not a valid file."
fi
