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
mkfs.fat -F32 "$part1"
mkswap -L SWAP "$part2"
mkfs.btrfs -f -L ROOT "$part3"

mount "$part3" /mnt
# --
# mount -o subvolid=5 "$part3" /mnt
# btrfs subvolume delete /mnt/@ || true
btrfs subvolume create /mnt/@
[ ! -d /mnt/@home ] && btrfs subvolume create /mnt/@home
[ ! -d /mnt/@var ] && btrfs subvolume create /mnt/@var

umount /mnt

mount -o noatime,compress=zstd,subvol=@ "$part3" /mnt
mkdir -p /mnt/{home,var}
mount -o noatime,compress=zstd,subvol=@home "$part3" /mnt/home
mount -o noatime,compress=zstd,subvol=@var "$part3" /mnt/var

# Mount EFI System Partition
mkdir -p /mnt/boot
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
arch-chroot /mnt /bin/bash <<'EOF'
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
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

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
freshclam
systemctl enable clamav-daemon.service

# Clean up package cache and Wrapping up
pacman -Scc --noconfirm
EOF

# Unmount and finalize
umount -lR /mnt
echo "Installation completed. Please reboot your system."
