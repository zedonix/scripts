#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 file1 [file2 ...]"
    exit 1
fi

for input in "$@"; do
    if [[ ! -f "$input" ]]; then
        echo "Skipping '$input': Not a valid file."
        continue
    fi

    ext="${input##*.}"
    name="${input%.*}"
    ext_lc="${ext,,}"

    case "$ext_lc" in
        docx | md | markdown | html | txt)
            echo "Converting '$input' with Pandoc..."
            pandoc "$input" -o "$name.pdf" --pdf-engine=pdflatex
            ;;
        png | jpg | jpeg | webp)
            echo "Converting '$input' with ImageMagick..."
            convert "$input" "$name.pdf"
            ;;
        *)
            echo "Unsupported file type: '$input'"
            ;;
    esac
done
