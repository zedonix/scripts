#!/usr/bin/env bash
set -e

SRC_DIR="$HOME/Downloads/GruvboxGtk"
DEST_DIR="$HOME/.local/share/themes"
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
find /usr/share/applications -iname '*.desktop' -print0 | while IFS= read -r -d $'\0' d; do
  mime_types=$(grep -m1 '^MimeType=' "$d" | cut -d= -f2)
  [[ -z "$mime_types" ]] && continue
  IFS=';' read -ra mimes <<< "$mime_types"
  for m in "${mimes[@]}"; do
    [[ -z "$m" ]] && continue
    xdg-mime default "$(basename "$d")" "$m"
  done
done
for type in pdf x-pdf fdf xdp xfdf pdx; do xdg-mime default org.pwmt.zathura.desktop application/$type; done
for type in jpeg svg png gif webp bmp tiff; do xdg-mime default swayimg.desktop image/$type; done

# Firefox user.js linking
git config --global user.email "zedonix@proton.me"
git config --global user.name "piyush"
git config --global credential.https://github.com.helper ''
git config --global --add credential.https://github.com.helper "!$(which gh) auth git-credential"
gh auth login -p ssh
if [ -d ~/.mozilla/firefox ]; then
  dir=$(ls ~/.mozilla/firefox/ | grep ".default-release" | head -n1)
  if [ -n "$dir" ]; then
      ln -sf /home/$USER/.dotfiles/user.js /home/$USER/.mozilla/firefox/$dir/user.js
  fi
fi

# PhotoGimp setup
cd ~/Downloads
gh release download --pattern '*linux*' -R Diolinux/PhotoGIMP
unzip PhotoGIMP-linux.zip
cp -r PhotoGIMP-linux/.config/ ~/

# UFW setup
sudo ufw allow 20/tcp # ftp
sudo ufw allow 21/tcp # ftp (I am server)
sudo ufw limit 22/tcp # ssh
sudo ufw allow 80/tcp # https (I am server)
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo systemctl enable ufw

# Libvirt setup
# sudo virsh net-autostart default

# Flatpak setup
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Snapper setup
if mountpoint -q /.snapshots; then
  sudo umount /.snapshots/
fi
[[ -d /.snapshots ]] && sudo rm -rf /.snapshots/
sudo snapper -c root create-config / || true
sudo snapper -c home create-config /home || true
sudo mount -a

sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
sudo systemctl enable --now grub-btrfsd

sudo sed -i \
  -e 's/^TIMELINE_MIN_AGE="3600"/TIMELINE_MIN_AGE="1800"/' \
  -e 's/^TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' \
  -e 's/^TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="7"/' \
  -e 's/^TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/' \
  -e 's/^TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/' \
  "/etc/snapper/configs/root"

sudo sed -i \
  -e 's/^TIMELINE_MIN_AGE="3600"/TIMELINE_MIN_AGE="1800"/' \
  -e 's/^TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' \
  -e 's/^TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="0"/' \
  -e 's/^TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/' \
  -e 's/^TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/' \
  "/etc/snapper/configs/home"

# A cron job
(crontab -l ; echo "@daily $(which trash-empty) 30") | crontab -

# Running aur.sh
bash ~/.scripts/aur.sh
