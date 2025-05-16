#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$XDG_STATE_HOME"/bash

SRC_DIR="/home/${USER}/Downloads/GruvboxGtk"
DEST_DIR="${HOME}/.local/share"
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
shopt -s nullglob
for desktopfile in /usr/share/applications/*.desktop; do
  mime_types=$(grep '^MimeType=' "$desktopfile" | head -n1 | cut -d= -f2)
  if [[ -n $mime_types ]]; then
    IFS=';' read -ra mimes <<< "$mime_types"
    for mime in "${mimes[@]}"; do
      # skip empty mime types
      [[ -z "$mime" ]] && continue
      xdg-mime default "$(basename "$desktopfile")" "$mime"
    done
  fi
done
for type in pdf x-pdf fdf xdp xfdf pdx; do xdg-mime default org.pwmt.zathura.desktop application/$type; done
for type in jpeg svg png gif webp bmp tiff; do xdg-mime default swayimg.desktop image/$type; done

# Snapper setup
if mountpoint -q /.snapshots; then
  umount /.snapshots/
fi
rm -rf /.snapshots/
sudo snapper -c root create-config / || true
sudo snapper -c home create-config /home || true
sudo snapper -c var create-config /var || true
mount -a

sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
sudo systemctl enable --now grub-btrfsd

# Libvirt setup
sudo virsh net-autostart default

# Firefox user.js linking
firefox
profile_dir=$(find ~/.mozilla/firefox -maxdepth 1 -type d -name '*.default-release' | head -n1)
if [[ -n "$profile_dir" ]]; then
  ln -sf "$HOME/.dotfiles/user.js" "$profile_dir/user.js"
fi

# UFW setup
sudo ufw allow 20/tcp
sudo ufw allow 21/tcp
sudo ufw limit 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo systemctl enable ufw

# Enable ananicy-cpp(nice value) and fstrim(ssd)
sudo systemctl enable --now ananicy-cpp.service
sudo systemctl enable fstrim.timer

# Flatpak setup
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# zram setup
printf '[zram0]\nzram-size = ram * 2\ncompression-algorithm = zstd\nswap-priority = 100\nfs-type = swap\n' | sudo tee /etc/systemd/zram-generator.conf

# Take snapshot befor aur
sudo snapper -c root create -d "Before initial AUR"

# Running aur.sh
bash ~/.scripts/aur.sh
