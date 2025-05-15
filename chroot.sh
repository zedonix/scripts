#!/bin/bash
set -euo pipefail

# Configuration
timezone="Asia/Kolkata"
hostname="archlinux"

# --- Root password setup with retry ---
while true; do
  echo "Setting root password..."
  if passwd; then
    break
  else
    echo "Password setup failed. Please try again."
  fi
done

# --- User Setup with username prompt loop ---
while true; do
  read -p "Username: " user
  if [[ -z "$user" ]]; then
    echo "Username cannot be empty. Please enter a username."
    continue
  fi
  break
done

if ! id "$user" &>/dev/null; then
  useradd -m -G wheel,storage,power,video,audio,libvirt,kvm -s /bin/bash "$user"
  # --- User password setup with retry ---
  while true; do
    echo "Setting user password..."
    if passwd "$user"; then
      break
    else
      echo "Password setup failed. Please try again."
    fi
  done
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
echo "%wheel ALL=(ALL) ALL" | sudo tee /etc/sudoers.d/wheel

# Host Configuration
echo "$hostname" > /etc/hostname
echo "127.0.0.1  localhost" > /etc/hosts
echo "::1        localhost" >> /etc/hosts
echo "127.0.1.1  $hostname.localdomain  $hostname" >> /etc/hosts

# Bootloader
pacman -S --noconfirm grub grub-btrfs efibootmgr os-prober
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i '/^#GRUB_DISABLE_OS_PROBER=false$/c\GRUB_DISABLE_OS_PROBER=false' /etc/default/grub
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
  mkdir -p ~/Downloads ~/Documents/home ~/Public ~/Templates ~/Videos ~/Pictures/Screenshots ~/.config

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
'

# Polkit/Firefox policy
mkdir -p /etc/firefox/policies
ln -sf /home/"$user"/.dotfiles/policies.json /etc/firefox/policies/policies.json

# Services
systemctl enable NetworkManager
systemctl enable libvirtd
freshclam
systemctl enable clamav-daemon.service

# Clean up package cache and Wrapping up
pacman -Scc --noconfirm
