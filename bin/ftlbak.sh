#!/usr/bin/env bash
cd ~/.local/share/FasterThanLight || exit
mv -- *.bak ~/Desktop/ftl/
for f in *.sav *.ini; do cp "$f" "$f.bak"; done
