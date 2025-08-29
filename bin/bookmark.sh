#!/usr/bin/env bash

trash ~/Documents/projects/default/dotfiles/book*
latest=$(find ~/.mozilla/firefox/*.default-release/bookmarkbackups -type f -name '*.jsonlz4' -printf '%T@ %p\n' |
  sort -nr |
  awk 'NR==1 {print substr($0, index($0,$2))}')
cp -f "$latest" ~/Documents/projects/default/dotfiles/
