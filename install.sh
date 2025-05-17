#!/bin/bash
set -euo pipefail

# --- Prompt Section (collect all user input here) ---

# Disk Selection
disks=($(lsblk -dno NAME))
echo "Available disks:"
select disk_input in "${disks[@]}"; do
  disk="/dev/${disk_input}"
  if [ -b "$disk" ]; then
    break
  else
    echo "Invalid selection. Try again."
  fi
done

# Hostname
while true; do
  read -p "Hostname: " hostname
  # RFC 1123: 1-63 chars, letters, digits, hyphens, not start/end with hyphen
  if [[ ! "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
    echo "Invalid hostname. Use 1-63 letters, digits, or hyphens (not starting or ending with hyphen)."
    continue
  fi
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
  # Linux username: 1-32 chars, start with letter, then letters/digits/_/-
  if [[ ! "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    echo "Invalid username. Use 1-32 lowercase letters, digits, underscores, or hyphens, starting with a letter or underscore."
    continue
  fi
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
  part_prefix="${disk}p"
else
  part_prefix="${disk}"
fi

part1="${part_prefix}1"
part2="${part_prefix}2"

# Partitioning --
parted -s "$disk" mklabel gpt
parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
parted -s "$disk" set 1 esp on
parted -s "$disk" mkpart primary btrfs 1025MiB 100%

# Formatting
mkfs.vfat -F 32 -n EFI "$part1"
mkfs.btrfs -f -L ROOT "$part2"

mount "$part2" /mnt
# --

# mount -o subvolid=5 "$part2" /mnt
# btrfs subvolume delete /mnt/@ || true
btrfs subvolume create /mnt/@
[ ! -d /mnt/@home ] && btrfs subvolume create /mnt/@home
[ ! -d /mnt/@var ] && btrfs subvolume create /mnt/@var
[ ! -d /mnt/@snapshots ] && btrfs subvolume create /mnt/@snapshots

umount /mnt

mount -o noatime,compress=lzo,ssd,space_cache=v2,discard=async,subvol=@ "$part2" /mnt
mkdir -p /mnt/{home,var,.snapshots}
mount -o noatime,compress=lzo,ssd,space_cache=v2,discard=async,subvol=@home "$part2" /mnt/home
mount -o noatime,compress=lzo,ssd,space_cache=v2,discard=async,subvol=@var "$part2" /mnt/var
mount -o noatime,compress=zstd,ssd,space_cache=v2,discard=async,subvol=@snapshots "$part2" /mnt/.snapshots

# Mount EFI System Partition
mkdir -p /mnt/boot
mount "$part1" /mnt/boot

# Pacstrap stuff
install_pkgs=(
    base base-devel linux-zen linux-zen-headers linux-firmware sudo btrfs-progs
    man-db man-pages networkmanager network-manager-applet bash-completion ananicy-cpp zram-generator acpid power-profiles-daemon
    ntfs-3g exfat-utils mtools dosfstools intel-ucode inotify-tools
    grub grub-btrfs efibootmgr os-prober snapper snap-pac
    qemu-desktop virt-manager vde2 dnsmasq libvirt bridge-utils openbsd-netcat
    openssh ncdu bat eza fzf git github-cli ripgrep ripgrep-all fd sqlite dysk cronie ufw clamav
    sassc udiskie gvfs gvfs-mtp gvfs-gphoto2 unrar 7zip unzip rsync jq reflector polkit polkit-gnome
    pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-audio pipewire-jack
    xorg-xwayland xdg-desktop-portal-wlr xdg-desktop-portal-gtk
    sway swaybg swaylock swayidle swayimg autotiling flatpak ly hyprpicker
    celluloid fuzzel qalculate-gtk discord firefox zathura kanshi pcmanfm-gtk3 gimp file-roller
    easyeffects audacity lsp-plugins-lv2 mda.lv2 zam-plugins-lv2 calf
    foot nvtop htop fastfetch newsboat neovim tmux asciinema trash-cli wget yt-dlp aria2
    papirus-icon-theme noto-fonts noto-fonts-cjk noto-fonts-emoji ttc-iosevka ttf-iosevkaterm-nerd gnu-free-fonts
    wl-clip-persist wl-clipboard cliphist libnotify swaync grim slurp swayosd
    texlive-latex pandoc zathura-pdf-mupdf
    lua python uv python-black stylua pyright bash-language-server ollama
)

# Pacstrap with error handling
reflector --country 'India' --latest 10 --age 24 --sort rate --save /etc/pacman.d/mirrorlist
if ! pacstrap /mnt "${install_pkgs[@]}"; then
  echo "pacstrap failed. Please check the package list and network connection."
  exit 1
fi

# System Configuration
genfstab -U /mnt > /mnt/etc/fstab

# Exporting variables for chroot
cat > /mnt/root/install.conf <<EOF
hostname=$hostname
root_password=$root_password
user=$user
user_password=$user_password
EOF
chmod 600 /mnt/root/install.conf

# Run chroot.sh
cp "$(dirname "$0")/chroot.sh" /mnt/root/chroot.sh
chmod +x /mnt/root/chroot.sh
arch-chroot /mnt /root/chroot.sh

# Unmount and finalize
if mountpoint -q /mnt; then
  umount -R /mnt
fi
echo "Installation completed. Please reboot your system."
