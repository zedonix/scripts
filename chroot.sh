#!/bin/bash
set -euo pipefail

# Configuration
timezone="Asia/Kolkata"
hostname="archlinux"

echo "Setting root password..."
passwd

# User Setup
read -p "Username: " user
if ! id "$user" &>/dev/null; then
  useradd -m -G wheel,storage,power,video,audio,libvirt -s /bin/bash "$user"
  echo "Setting user password..."
  passwd "$user"
else
  echo "User $user already exists, skipping creation."
fi

# Local Setup
ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
hwclock --systohc
sed -i "/en_US.UTF-8/s/^#//" /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Sudo Configuration
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Host Configuration
echo "$hostname" > /etc/hostname
echo "127.0.0.1  localhost" > /etc/hosts
echo "::1        localhost" >> /etc/hosts
echo "127.0.1.1  $hostname.localdomain  $hostname" >> /etc/hosts

# Bootloader
pacman -S --noconfirm grub grub-btrfs efibootmgr os-prober
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
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
systemctl enable reflector.timer

# Copy config and dotfiles as the user
su - "$user" -c '
  mkdir -p ~/Downloads ~/Documents ~/Public ~/Templates ~/Videos ~/Pictures/Screenshots ~/PenDrive ~/.config

  git clone https://github.com/zedonix/scripts.git ~/.scripts
  git clone https://github.com/zedonix/dotfiles.git ~/.dotfiles
  git clone https://github.com/zedonix/GruvboxGtk.git ~/Downloads/GruvboxGtk

  ln -sf ~/.dotfiles/.bashrc ~/.bashrc

  # Firefox user.js linking
  if [ -d ~/.mozilla/firefox ]; then
    dir=$(ls ~/.mozilla/firefox/ | grep ".default-release" | head -n1)
    if [ -n "$dir" ]; then
      ln -sf ~/.dotfiles/user.js ~/.mozilla/firefox/$dir/user.js
    fi
  fi

  # .config links
  for link in foot fuzzel htop newsboat nvim sway tmux zathura swaync mpv mako; do
    ln -sf ~/.dotfiles/.config/$link/ ~/.config
  done
  git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
'

# Polkit/Firefox policy
mkdir -p /etc/firefox/policies
ln -sf /home/"$user"/.dotfiles/policies.json /etc/firefox/policies/policies.json

# Services
systemctl enable NetworkManager
systemctl enable libvirtd
systemctl start libvirtd
sleep 2 # Wait a moment for the daemon to start
virsh net-autostart default
freshclam
systemctl enable clamav-daemon.service

# Clean up package cache and Wrapping up
pacman -Scc --noconfirm
