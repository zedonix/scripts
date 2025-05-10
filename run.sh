#!/usr/bin/env bash

set -e

SRC_DIR="/home/piyush/Downloads/GruvboxGtk"
DEST_DIR="${HOME}/.themes"
THEME_NAME="Gruvbox-Dark"
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
gsettings set org.gnome.desktop.interface gtk-theme 'Gruvbox-Dark'
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Mime setup
find /usr/share/applications ~/.local/share/applications -iname '*.desktop' -print0 | while IFS= read -r -d $'\0' d; do
  for m in $(grep MimeType "$d" | cut -d= -f2 | tr ";" " "); do
    echo xdg-mime default "'$d'" "'$m'"
  done
done
for type in pdf x-pdf fdf xdp xfdf pdx; do xdg-mime default org.pwmt.zathura.desktop application/$type; done

# Snapper setup
sudo snapper -c root create-config /
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
sudo systemctl enable --now grub-btrfsd

# Libvirt setup
sudo virsh net-autostart default

# Firefox user.js linking
if [ -d ~/.mozilla/firefox ]; then
  dir=$(ls ~/.mozilla/firefox/ | grep ".default-release" | head -n1)
  if [ -n "$dir" ]; then
      ln -sf ~/.dotfiles/user.js ~/.mozilla/firefox/$dir/user.js
  fi
fi

# UFW setup
sudo ufw limit 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo systemctl enable ufw
