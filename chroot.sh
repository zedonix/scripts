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
#sed -i 's/^#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/' /etc/default/grub
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
  cp ~/.dotfiles/.config/sway/arch.png ~/Pictures/
  ln -sf ~/.dotfiles/.bashrc ~/.bashrc
  ln -sf ~/.dotfiles/home.html ~/Documents/home/home.html
  ln -sf ~/.dotfiles/archlinux.png ~/Documents/home/archlinux.png
  ln -sf ~/.dotfiles/.config/mimeapps.list ~/.config/mimeapps.list

  for link in foot fuzzel mako mpv newsboat nvim sway swaync tmux zathura; do
    ln -sf ~/.dotfiles/.config/$link/ ~/.config
  done
  git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

  # PhotoGimp setup
  cd ~/Downloads
  git clone --filter=blob:none --no-checkout https://github.com/Diolinux/PhotoGIMP.git
  cd PhotoGIMP
  git sparse-checkout init --cone
  git sparse-checkout set .config
  git checkout
  cp -r .config/* ~/.config

  # Git config
  git config --global user.email "zedonix@proton.me"
  git config --global user.name "piyush"
'
# Root .config
mkdir -p /root/.config
echo '[ -f ~/.bashrc ] && . ~/.bashrc' > /root/.bash_profile
mkdir /root/.config
ln -sf /home/"$user"/.dotfiles/.bashrc ~/.bashrc
ln -sf /home/"$user"/.dotfiles/.config/nvim/ ~/.config

# tldr wiki setup
curl -L "https://raw.githubusercontent.com/filiparag/wikiman/master/Makefile" -o "wikiman-makefile"
make -f ./wikiman-makefile source-tldr
make -f ./wikiman-makefile source-install
make -f ./wikiman-makefile clean

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
modprobe btusb || true
systemctl enable NetworkManager NetworkManager-dispatcher sshd ananicy-cpp fstrim.timer ollama ly acpid cronie # tlp bluetooth libvirtd
systemctl enable btrfs-scrub@-.timer btrfs-scrub@home.timer btrfs-scrub@var.timer
systemctl mask systemd-rfkill systemd-rfkill.socket
systemctl disable NetworkManager-wait-online.service systemd-networkd.service systemd-resolved

# Prevent NetworkManager from using systemd-resolved
sudo mkdir -p /etc/NetworkManager/conf.d
echo -e "[main]\nsystemd-resolved=false" | sudo tee /etc/NetworkManager/conf.d/no-systemd-resolved.conf > /dev/null

# Set DNS handling to 'default'
echo -e "[main]\ndns=default" | sudo tee /etc/NetworkManager/conf.d/dns.conf > /dev/null

# Configure static IP, gateway, and custom DNS
nmcli con mod "Wired connection 1" \
  ipv4.method manual \
  ipv4.addresses 192.168.1.100/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "1.1.1.1,1.0.0.1"
nmcli con mod "Wired connection 1" ipv4.ignore-auto-dns yes

# Apply changes
nmcli con down "Wired connection 1"
nmcli con up "Wired connection 1"

# Clamav setup
freshclam
touch /var/log/clamav/freshclam.log
chown clamav:clamav /var/log/clamav/freshclam.log
systemctl enable clamav-daemon clamav-freshclam

# Clean up package cache and Wrapping up
pacman -Scc --noconfirm
