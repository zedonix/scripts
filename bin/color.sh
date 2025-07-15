#!/bin/sh

# Temporary screenshot path
TMP_IMAGE="/tmp/screen_color_pick.png"

# Take full-screen screenshot
grim "$TMP_IMAGE"

# Get X and Y coordinates from slurp
read X Y <<EOF
$(slurp -p -f "%x %y")
EOF

# Exit if no selection
[ -z "$X" ] || [ -z "$Y" ] && exit 1

# Extract color at the selected pixel
COLOR=$(magick "$TMP_IMAGE" -format "%[hex:p{$X,$Y}]" info:)

# Copy to clipboard in #rrggbb format
echo "#$COLOR" | wl-copy
