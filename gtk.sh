#!/usr/bin/env bash

set -e

# Paths
SRC_DIR="/home/piyush/scripts/GruvboxGtk"
DEST_DIR="${HOME}/.themes"
THEME_NAME="Gruvbox-Dark"

# Check for sassc
if ! command -v sassc >/dev/null; then
    echo "Error: sassc is required but not installed."
    exit 1
fi

# Create theme directory
THEME_DIR="${DEST_DIR}/${THEME_NAME}"
rm -rf "${THEME_DIR}"
mkdir -p "${THEME_DIR}"

# --- GTK2 ---
mkdir -p "${THEME_DIR}/gtk-2.0"
cp -r "${SRC_DIR}/main/gtk-2.0/common/"*'.rc' "${THEME_DIR}/gtk-2.0" 2>/dev/null || true
cp -r "${SRC_DIR}/assets/gtk-2.0/assets-common-Dark" "${THEME_DIR}/gtk-2.0/assets" 2>/dev/null || true
cp -r "${SRC_DIR}/assets/gtk-2.0/assets-Dark/"*.png "${THEME_DIR}/gtk-2.0/assets" 2>/dev/null || true

# --- GTK3 ---
mkdir -p "${THEME_DIR}/gtk-3.0"
cp -r "${SRC_DIR}/assets/gtk/scalable" "${THEME_DIR}/gtk-3.0/assets" 2>/dev/null || true
if [ -f "${SRC_DIR}/main/gtk-3.0/gtk-Dark.scss" ]; then
    sassc -M -t expanded "${SRC_DIR}/main/gtk-3.0/gtk-Dark.scss" "${THEME_DIR}/gtk-3.0/gtk.css"
    cp "${THEME_DIR}/gtk-3.0/gtk.css" "${THEME_DIR}/gtk-3.0/gtk-dark.css"
fi

# --- GTK4 ---
mkdir -p "${THEME_DIR}/gtk-4.0"
cp -r "${SRC_DIR}/assets/gtk/scalable" "${THEME_DIR}/gtk-4.0/assets" 2>/dev/null || true
if [ -f "${SRC_DIR}/main/gtk-4.0/gtk-Dark.scss" ]; then
    sassc -M -t expanded "${SRC_DIR}/main/gtk-4.0/gtk-Dark.scss" "${THEME_DIR}/gtk-4.0/gtk.css"
    cp "${THEME_DIR}/gtk-4.0/gtk.css" "${THEME_DIR}/gtk-4.0/gtk-dark.css"
fi

# --- index.theme ---
cat > "${THEME_DIR}/index.theme" <<EOF
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=${THEME_NAME}
Comment=Gruvbox Dark GTK Theme
EOF

echo "Gruvbox Dark theme installed for GTK2, GTK3, and GTK4 in ${THEME_DIR}"

gsettings set org.gnome.desktop.interface gtk-theme 'Gruvbox-Dark'
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
