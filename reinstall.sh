#!/bin/bash
set -euo pipefail

# Disk Selection
echo "Available disks:"
lsblk
read -p "Enter Disk (e.g. nvme0n1 or sda): " disk_input
disk="/dev/${disk_input%/}"

# Disk Checking
if [ ! -b "$disk" ]; then
  echo "Disk $disk does not exist. Exiting."
  exit 1
fi

# Safety Confirmation
echo "WARNING: This will ERASE the root, home, and var subvolumes and reinstall the system on $disk!"
read -p "Type 'yes' to continue: " confirm
[[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 1; }

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

# Mount the Btrfs partition's top-level
mount -o subvolid=5 "$part3" /mnt

# Delete and recreate subvolumes
for subvol in @ @home @var; do
  if [ -d "/mnt/$subvol" ]; then
    echo "Deleting old subvolume ($subvol)..."
    btrfs subvolume delete "/mnt/$subvol"
  fi
done

echo "Creating new subvolumes..."
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var

umount /mnt

# Mount subvolumes
mount -o noatime,compress=zstd,subvol=@ "$part3" /mnt
mkdir -p /mnt/{boot,home,var}
mount -o noatime,compress=zstd,subvol=@home "$part3" /mnt/home
mount -o noatime,compress=zstd,subvol=@var "$part3" /mnt/var

# Mount EFI and swap
mount "$part1" /mnt/boot
swapon "$part2"

# Package List
install_pkgs=(
    base base-devel linux linux-headers linux-firmware sudo man-db man-pages snapper btrfs-progs uv qemu-desktop virt-manager vde2 bash-completion
    openssh ncdu htop fastfetch bat eza fzf git github-cli ripgrep ripgrep-all sqlite ntfs-3g exfat-utils mtools dosfstools dnsmasq dysk gvfs
    networkmanager ufw newsboat pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-audio pipewire-jack mpv sassc libvirt fuzzel udiskie
    xorg-xwayland xdg-desktop-portal-wlr xdg-desktop-portal-gtk sway swaybg swayimg swaylock swayidle foot wl-clip-persist swaync autotiling
    papirus-icon-theme noto-fonts noto-fonts-cjk noto-fonts-emoji ttc-iosevka ttf-iosevkaterm-nerd yt-dlp aria2 bridge-utils openbsd-netcat
    neovim tmux zathura texlive-latex unrar 7zip rsync grim slurp flameshot pcmanfm-gtk3 gimp clamav intel-ucode inotify-tools discord firefox
    wl-clipboard cliphist libnotify asciinema reflector polkit polkit-gnome lua python python-black stylua pyright jq swayosd gnu-free-fonts
)

# Ensure reflector is installed (if not already)
if ! command -v reflector &>/dev/null; then
  pacman -Sy --noconfirm reflector
fi

# Update mirrors
reflector --country 'India' --latest 10 --age 24 --sort rate --save /etc/pacman.d/mirrorlist

# Pacstrap with error handling
set +e
pacstrap /mnt "${install_pkgs[@]}"
if [ $? -ne 0 ]; then
  echo "pacstrap failed. Please check the package list and network connection."
  exit 1
fi
set -e

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Copy chroot script and run in chroot
cp "$(dirname "$0")/chroot.sh" /mnt/root/chroot.sh
chmod +x /mnt/root/chroot.sh
arch-chroot /mnt /root/chroot.sh

# Unmount and finalize
umount -lR /mnt
echo "Reinstallation completed. Please reboot your system."
