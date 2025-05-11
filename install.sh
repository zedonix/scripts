#!/bin/bash
set -euo pipefail

# Disk Selection
echo "Available disks:"
lsblk
read -p "Enter Disk: " disk_input
disk="/dev/${disk_input%/}"

# Disk Checking
if [ ! -b "$disk" ]; then
  echo "Disk $disk does not exist. Exiting."
  exit 1
fi

# Partition Naming
if [[ "$disk" == *nvme* ]]; then
  part1="${disk}p1"
  part2="${disk}p2"
  part3="${disk}p3"
else
  part1="${disk}1"
  part2="${disk}2"
  part3="${disk}3"
fi

# Partitioning --
parted -s "$disk" mklabel gpt

# Swap size configuration
swap_size_gib=8
swap_mib=$((swap_size_gib * 1024))

# Partition Layout
parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
parted -s "$disk" set 1 esp on
parted -s "$disk" mkpart primary linux-swap 1025MiB $((1025 + swap_mib))MiB
parted -s "$disk" mkpart primary btrfs $((1025 + swap_mib))MiB 100%

# Formatting
mkfs.fat -F32 -n BOOT "$part1"
mkswap -L SWAP "$part2"
mkfs.btrfs -f -L ROOT "$part3"

mount "$part3" /mnt
# --
# mount -o subvolid=5 "$part3" /mnt
# btrfs subvolume delete /mnt/@ || true
btrfs subvolume create /mnt/@
if [ ! -d /mnt/@home ]; then
  btrfs subvolume create /mnt/@home
fi
if [ ! -d /mnt/@var ]; then
  btrfs subvolume create /mnt/@var
fi

umount /mnt

mount -o noatime,compress=zstd,subvol=@ "$part3" /mnt
mkdir -p /mnt/{home,var}
mount -o noatime,compress=zstd,subvol=@home "$part3" /mnt/home
mount -o noatime,compress=zstd,subvol=@var "$part3" /mnt/var

# Mount EFI System Partition at /efi
mkdir -p /mnt/boot # --
mount "$part1" /mnt/boot
swapon "$part2"

# Base Installation
install_pkgs=(
    base base-devel linux linux-headers linux-firmware sudo man-db man-pages snapper btrfs-progs uv qemu-desktop virt-manager vde2 bash-completion
    openssh ncdu htop fastfetch bat eza fzf git github-cli ripgrep ripgrep-all sqlite ntfs-3g exfat-utils mtools dosfstools dnsmasq dysk gvfs
    networkmanager ufw newsboat pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-audio pipewire-jack mpv sassc libvirt fuzzel udiskie
    xorg-xwayland xdg-desktop-portal-wlr xdg-desktop-portal-gtk sway swaybg swaylock swayidle foot wl-clip-persist swaync autotiling swayimg
    papirus-icon-theme noto-fonts noto-fonts-cjk noto-fonts-emoji ttc-iosevka ttf-iosevkaterm-nerd yt-dlp aria2 bridge-utils openbsd-netcat flatpak
    neovim tmux zathura texlive-latex unrar 7zip unzip rsync grim slurp flameshot pcmanfm-gtk3 gimp clamav intel-ucode inotify-tools discord firefox
    wl-clipboard cliphist libnotify asciinema reflector polkit polkit-gnome lua python python-black stylua pyright jq swayosd gnu-free-fonts zathura-pdf-mupdf
)

# Ensure reflector is installed (if not already)
if ! command -v reflector &>/dev/null; then
  pacman -Sy --noconfirm reflector
fi

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

cp "$(dirname "$0")/chroot.sh" /mnt/root/chroot.sh
chmod +x /mnt/root/chroot.sh
arch-chroot /mnt /root/chroot.sh

# Unmount and finalize
umount -lR /mnt
echo "Installation completed. Please reboot your system."
