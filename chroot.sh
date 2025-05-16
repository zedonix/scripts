#!/bin/bash
set -euo pipefail

# Configuration
timezone="Asia/Kolkata"

# Load variables from install.conf
source /root/install.conf

# --- Set hostname ---
echo "$hostname" > /etc/hostname
echo "127.0.0.1  localhost" > /etc/hosts
echo "::1        localhost" >> /etc/hosts
echo "127.0.1.1  $hostname.localdomain  $hostname" >> /etc/hosts

# --- Set root password ---
echo "root:$root_password" | chpasswd

# --- Create user and set password ---
if ! id "$user" &>/dev/null; then
  useradd -m -G wheel,storage,video,audio,kvm -s /bin/bash "$user"
  echo "$user:$user_password" | chpasswd
else
  echo "User $user already exists, skipping creation."
fi

# Local Setup
ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
hwclock --systohc
sed -i 's/#en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Sudo Configuration
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
if grep -q "^#GRUB_DISABLE_OS_PROBER=false" /etc/default/grub; then
  sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
elif ! grep -q "^GRUB_DISABLE_OS_PROBER=" /etc/default/grub; then
  echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
fi
grub-mkconfig -o /boot/grub/grub.cfg

# Reflector and pacman Setup
sed -i '/^#Color$/c\Color' /etc/pacman.conf
mkdir -p /etc/xdg/reflector
cat > /etc/xdg/reflector/reflector.conf << REFCONF
--save /etc/pacman.d/mirrorlist
--protocol https
--country India
--latest 10
--age 24
--sort rate
REFCONF
reflector --country 'India' --latest 10 --age 24 --sort rate --save /etc/pacman.d/mirrorlist
systemctl enable reflector.timer

# Installing stuff
install_pkgs=( 
    man-db man-pages network-manager-applet bash-completion ananicy-cpp zram-generator acpid power-profiles-daemon
    ntfs-3g exfat-utils mtools dosfstools intel-ucode inotify-tools
    grub grub-btrfs efibootmgr os-prober snapper
    qemu-desktop virt-manager vde2 dnsmasq libvirt bridge-utils openbsd-netcat
    openssh ncdu bat eza fzf git github-cli ripgrep ripgrep-all sqlite dysk cronie ufw clamav
    sassc udiskie gvfs yt-dlp aria2 unrar 7zip unzip rsync jq reflector polkit polkit-gnome wget
    pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-audio pipewire-jack
    xorg-xwayland xdg-desktop-portal-wlr xdg-desktop-portal-gtk
    sway swaybg swaylock swayidle swayimg autotiling flatpak ly
    mpv fuzzel qalculate-gtk discord firefox zathura kanshi pcmanfm-gtk3 gimp
    easyeffects lsp-plugins-lv2 mda.lv2 zam-plugins-lv2 calf
    foot nvtop htop fastfetch newsboat neovim tmux asciinema
    papirus-icon-theme noto-fonts noto-fonts-cjk noto-fonts-emoji ttc-iosevka ttf-iosevkaterm-nerd gnu-free-fonts
    wl-clip-persist wl-clipboard cliphist libnotify swaync grim slurp swayosd
    texlive-latex pandoc zathura-pdf-mupdf hunspell hunspell-en_us nuspell enchant languagetool
    lua python uv python-black stylua pyright ollama
)
sudo pacman -Syu "${install_pkgs[@]}" --noconfirm
usermod -aG libvirt piyush

# Copy config and dotfiles as the user
su - "$user" -c '
  mkdir -p ~/Downloads ~/Documents/home ~/Public ~/Templates ~/Videos ~/Pictures/Screenshots ~/.config ~/.local/state/bash

  git clone https://github.com/zedonix/scripts.git ~/.scripts
  git clone https://github.com/zedonix/dotfiles.git ~/.dotfiles
  git clone https://github.com/zedonix/GruvboxGtk.git ~/Downloads/GruvboxGtk

  cp ~/.dotfiles/archpfp.png ~/Pictures/
  ln -sf ~/.dotfiles/.bashrc ~/.bashrc
  ln -sf ~/.dotfiles/home.html ~/Documents/home/home.html
  ln -sf ~/.dotfiles/archlinux.png ~/Documents/home/archlinux.png

  for link in foot fuzzel newsboat nvim sway tmux zathura swaync mpv mako; do
    ln -sf ~/.dotfiles/.config/$link/ ~/.config
  done
  git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  printf "[zram0]\nzram-size = ram * 2\ncompression-algorithm = zstd\nswap-priority = 100\nfs-type = swap\n" | sudo tee /etc/systemd/zram-generator.conf
'

# Polkit/Firefox policy
mkdir -p /etc/firefox/policies
ln -sf /home/"$user"/.dotfiles/policies.json /etc/firefox/policies/policies.json

# Services
systemctl enable NetworkManager libvirtd sshd ananicy-cpp.service fstrim.timer ollama.service ly.service acpid power-profiles-daemon.service
freshclam
systemctl enable clamav-daemon.service clamav-freshclam.service

# Clean up package cache and Wrapping up
pacman -Scc --noconfirm

# Delete password
shred -u /root/install.conf

echo "Chroot configuration complete."
