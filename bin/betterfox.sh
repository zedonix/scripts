#!/usr/bin/env bash

trash ~/Documents/projects/default/dotfiles/book* &>/dev/null
trash "$HOME/Downloads/user.js" &>/dev/null
trash "$HOME/Downloads/userMY.js" &>/dev/null

latest=$(find ~/.mozilla/firefox/*.default-esr/bookmarkbackups -type f -name '*.jsonlz4' -printf '%T@ %p\n' |
  sort -nr |
  awk 'NR==1 {print substr($0, index($0,$2))}')
cp -f "$latest" ~/Documents/projects/default/dotfiles/

awk '
BEGIN {skip=0}
{
    if ($0 ~ /START: MY OVERRIDES/) { skip=1; print; next }
    if (skip && $0 ~ /SECTION: SMOOTHFOX/) { skip=0; print; next }
    if (!skip) print
}
' "$HOME/Documents/projects/default/dotfiles/user.js" >"$HOME/Downloads/userMY.js"
curl -Lo "$HOME/Downloads/user.js" https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js
delta --side-by-side "$HOME/Downloads/userMY.js" "$HOME/Downloads/user.js"
