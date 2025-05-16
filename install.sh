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
[ ! -d /mnt/@.snapshots] && btrfs subvolume create /mnt/@/.snapshots

umount /mnt

mount -o noatime,compress=lzo,ssd,space_cache=v2,discard=async,subvol=@ "$part2" /mnt
mkdir -p /mnt/{home,var}
mount -o noatime,compress=lzo,ssd,space_cache=v2,discard=async,subvol=@home "$part2" /mnt/home
mount -o noatime,compress=lzo,ssd,space_cache=v2,discard=async,subvol=@var "$part2" /mnt/var
mount -o noatime,compress=,zstd,ssd,space_cache=v2,discard=async,subvol=@.snapshots "$part2" /mnt/.snapshots

# Mount EFI System Partition
mkdir -p /mnt/boot
mount "$part1" /mnt/boot

# Base Installation
install_pkgs=(
    base base-devel linux-zen linux-zen-headers linux-firmware 
    sudo man-db man-pages btrfs-progs networkmanager network-manager-applet bash-completion ananicy-cpp zram-generator
    ntfs-3g exfat-utils mtools dosfstools intel-ucode inotify-tools
    grub grub-btrfs efibootmgr os-prober snapper
    qemu-desktop virt-manager vde2 dnsmasq libvirt bridge-utils openbsd-netcat
    openssh ncdu bat eza fzf git github-cli ripgrep ripgrep-all sqlite dysk cronie ufw clamav
    sassc udiskie gvfs yt-dlp aria2 unrar 7zip unzip rsync jq reflector polkit polkit-gnome
    pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-audio pipewire-jack
    xorg-xwayland xdg-desktop-portal-wlr xdg-desktop-portal-gtk
    sway swaybg swaylock swayidle swayimg autotiling flatpak
    mpv fuzzel qalculate-gtk discord firefox zathura kanshi pcmanfm-gtk3 gimp
    easyeffects lsp-plugins-lv2 mda.lv2 zam-plugins-lv2 calf
    foot nvtop htop fastfetch newsboat neovim tmux asciinema
    papirus-icon-theme noto-fonts noto-fonts-cjk noto-fonts-emoji ttc-iosevka ttf-iosevkaterm-nerd gnu-free-fonts
    wl-clip-persist wl-clipboard cliphist libnotify swaync grim slurp swayosd
    texlive-latex pandoc zathura-pdf-mupdf hunspell hunspell-en_us nuspell enchant languagetool
    lua python uv python-black stylua pyright
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
