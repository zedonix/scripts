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
  useradd -m -G wheel,storage,video,audio,kvm,libvirt -s /bin/bash "$user"
  echo "$user:$user_password" | chpasswd
else
  echo "User $user already exists, skipping creation."
fi

# Local Setup
ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Sudo Configuration
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
echo "Defaults timestamp_timeout=-1" > /etc/sudoers.d/timestamp
chmod 440 /etc/sudoers.d/wheel /etc/sudoers.d/timestamp

# Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
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

  for link in foot fuzzel mako mpv newsboat nvim sway swaync tmux zathura; do
    ln -sf ~/.dotfiles/.config/$link/ ~/.config
  done
  git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
'

# Polkit/Firefox policy
mkdir -p /etc/firefox/policies
ln -sf /home/"$user"/.dotfiles/policies.json /etc/firefox/policies/policies.json

# Delete password
shred -u /root/install.conf

# zram config
cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram * 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

# Services
# ananicy-cpp = auto nice levels
# acpid = ACPI events such as pressing the power button or closing a laptop's lid
rfkill unblock bluetooth
# modprobe btusb
systemctl enable NetworkManager NetworkManager-dispatcher libvirtd sshd ananicy-cpp fstrim.timer ollama ly acpid cronie tlp bluetooth
systemctl enable btrfs-scrub@-.timer btrfs-scrub@home.timer btrfs-scrub@var.timer
systemctl mask systemd-rfkill systemd-rfkill.socket
systemctl disable NetworkManager-wait-online.service

# Clamav setup
freshclam
touch /var/log/clamav/freshclam.log
chown clamav:clamav /var/log/clamav/freshclam.log
systemctl enable clamav-daemon clamav-freshclam

# Clean up package cache and Wrapping up
pacman -Scc --noconfirm
