#!/bin/bash
set -euo pipefail

# --- Prompt Section (collect all user input here) ---

# Disk Selection
echo "Available disks:"
lsblk -d -o NAME,SIZE,MODEL
while true; do
  read -p "Enter Disk (e.g. sda, nvme0n1): " disk_input
  disk="/dev/${disk_input%/}"
  if [ ! -b "$disk" ]; then
    echo "Disk $disk does not exist. Try again."
    continue
  fi
  break
done

# Hostname
while true; do
  read -p "Hostname: " hostname
  [[ -z "$hostname" ]] && echo "Hostname cannot be empty." && continue
  break
done

# Root Password
while true; do
  read -s -p "Root password: " root_password
  echo
  read -s -p "Confirm root password: " root_password2
  echo
  [[ "$root_password" != "$root_password2" ]] && echo "Passwords do not match." && continue
  [[ -z "$root_password" ]] && echo "Password cannot be empty." && continue
  break
done

# Username
while true; do
  read -p "Username: " user
  [[ -z "$user" ]] && echo "Username cannot be empty." && continue
  break
done

# User Password
while true; do
  read -s -p "User password: " user_password
  echo
  read -s -p "Confirm user password: " user_password2
  echo
  [[ "$user_password" != "$user_password2" ]] && echo "Passwords do not match." && continue
  [[ -z "$user_password" ]] && echo "Password cannot be empty." && continue
  break
done

# Export variables for later use
export disk hostname root_password user user_password

# Partition Naming
if [[ "$disk" == *nvme* ]]; then
  part1="${disk}p1"
  part2="${disk}p2"
else
  part1="${disk}1"
  part2="${disk}2"
fi

# Partitioning --
parted -s "$disk" mklabel gpt
parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
parted -s "$disk" set 1 esp on
parted -s "$disk" mkpart primary btrfs 1025MiB 100%

# Formatting
mkfs.fat -F32 "$part1"
mkfs.btrfs -f -L ROOT "$part2"

mount "$part2" /mnt
# --

# mount -o subvolid=5 "$part2" /mnt
# btrfs subvolume delete /mnt/@ || true
btrfs subvolume create /mnt/@
[ ! -d /mnt/@home ] && btrfs subvolume create /mnt/@home
[ ! -d /mnt/@var ] && btrfs subvolume create /mnt/@var

umount /mnt

mount -o noatime,compress=lzo,ssd,space_cache=v2,discard=async,subvol=@ "$part2" /mnt
mkdir -p /mnt/{home,var}
mount -o noatime,compress=lzo,ssd,space_cache=v2,discard=async,subvol=@home "$part2" /mnt/home
mount -o noatime,compress=lzo,ssd,space_cache=v2,discard=async,subvol=@var "$part2" /mnt/var

# Mount EFI System Partition
mkdir -p /mnt/boot
mount "$part1" /mnt/boot

# Base Installation
install_pkgs=(
    base base-devel linux linux-headers linux-firmware sudo man-db man-pages snapper btrfs-progs qemu-desktop virt-manager vde2 bash-completion profile-sync-daemon
    openssh ncdu bat eza fzf git github-cli ripgrep ripgrep-all sqlite ntfs-3g exfat-utils mtools dosfstools dnsmasq dysk gvfs cronie uv network-manager-applet
    networkmanager ufw newsboat pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-audio pipewire-jack mpv sassc libvirt fuzzel udiskie nvtop ananicy-cpp
    xorg-xwayland xdg-desktop-portal-wlr xdg-desktop-portal-gtk sway swaybg swaylock swayidle foot wl-clip-persist swaync autotiling swayimg qalculate-gtk nmcli
    papirus-icon-theme noto-fonts noto-fonts-cjk noto-fonts-emoji ttc-iosevka ttf-iosevkaterm-nerd yt-dlp aria2 bridge-utils openbsd-netcat flatpak kanshi nmtui
    neovim tmux zathura texlive-latex unrar 7zip unzip rsync grim slurp pcmanfm-gtk3 gimp clamav intel-ucode inotify-tools discord firefox easyeffects pandoc
    wl-clipboard cliphist libnotify asciinema reflector polkit polkit-gnome lua python python-black stylua pyright jq swayosd gnu-free-fonts zathura-pdf-mupdf
    htop fastfetch zram-generator
)

# Rate and install the base system
reflector --country 'India' --latest 10 --age 24 --sort rate --save /etc/pacman.d/mirrorlist

# Pacstrap with error handling
set +e
pacstrap /mnt "${install_pkgs[@]}"
if [ $? -ne 0 ]; then
  echo "pacstrap failed. Please check the package list and network connection."
  exit 1
fi
set -e

# System Configuration
genfstab -U /mnt >> /mnt/etc/fstab


# Exporting variables for chroot
cat > /mnt/root/install.conf <<EOF
hostname=$hostname
root_password=$root_password
user=$user
user_password=$user_password
EOF

# Run chroot.sh
cp "$(dirname "$0")/chroot.sh" /mnt/root/chroot.sh
chmod +x /mnt/root/chroot.sh
arch-chroot /mnt /root/chroot.sh

# Unmount and finalize
umount -lR /mnt
echo "Installation completed. Please reboot your system."
