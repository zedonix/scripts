#!/bin/bash
set -euo pipefail

echo "Available disks:"
lsblk
read -p "Enter Disk (e.g. nvme0n1 or sda): " disk_input
disk="/dev/${disk_input%/}"

if [ ! -b "$disk" ]; then
  echo "Disk $disk does not exist. Exiting."
  exit 1
fi

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

# Delete and recreate the root subvolume (@)
if [ -d /mnt/@ ]; then
  echo "Deleting old root subvolume (@)..."
  btrfs subvolume delete /mnt/@
fi
echo "Creating new root subvolume (@)..."
btrfs subvolume create /mnt/@

umount /mnt

# Mount subvolumes
mount -o noatime,compress=zstd,subvol=@ "$part3" /mnt
mkdir -p /mnt/{boot,home,var}
mount -o noatime,compress=zstd,subvol=@home "$part3" /mnt/home
mount -o noatime,compress=zstd,subvol=@var "$part3" /mnt/var

# Mount EFI and swap
mount "$part1" /mnt/boot
swapon "$part2"

# Base Installation (customize your package list as needed)
install_pkgs=(
    base base-devel linux linux-headers linux-firmware sudo man-db man-pages snapper btrfs-progs uv qemu-desktop virt-manager vde2 bash-completion
    openssh ncdu htop fastfetch bat eza fzf git github-cli ripgrep ripgrep-all sqlite ntfs-3g exfat-utils mtools dosfstools dnsmasq dysk
    networkmanager ufw newsboat pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-audio pipewire-jack mpv sassc libvirt fuzzel udiskie
    xorg-xwayland xdg-desktop-portal-wlr xdg-desktop-portal-gtk sway swaybg swayimg swaylock swayidle foot wl-clip-persist swaync autotiling
    papirus-icon-theme noto-fonts noto-fonts-cjk noto-fonts-emoji ttc-iosevka ttf-iosevkaterm-nerd yt-dlp aria2 bridge-utils openbsd-netcat
    neovim tmux zathura texlive-latex unrar 7zip rsync grim slurp flameshot pcmanfm-gtk3 gimp clamav intel-ucode inotify-tools discord firefox
    wl-clipboard cliphist libnotify asciinema reflector polkit polkit-gnome lua python python-black stylua pyright jq swayosd gnu-free-fonts
)

reflector --country 'India' --latest 10 --age 24 --sort rate --save /etc/pacman.d/mirrorlist

pacstrap /mnt "${install_pkgs[@]}"

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot for configuration
arch-chroot /mnt /bin/bash -c "
    timezone=\"Asia/Kolkata\"
    hostname=\"archlinux\"

    echo \"Setting root password...\"
    passwd

    # User Setup (skip if user already exists)
    read -p \"Username: \" user
    if ! id \"\$user\" &>/dev/null; then
        useradd -m -G wheel,storage,power,video,audio,libvirt -s /bin/bash \"\$user\"
        echo \"Setting user password...\"
        passwd \"\$user\"
    else
        echo \"User \$user already exists, skipping creation.\"
    fi

    # Local Setup
    ln -sf \"/usr/share/zoneinfo/\$timezone\" /etc/localtime
    hwclock --systohc
    sed -i \"/en_US.UTF-8/s/^#//\" /etc/locale.gen
    locale-gen
    echo \"LANG=en_US.UTF-8\" > /etc/locale.conf

    # Sudo Configuration
    echo \"%wheel ALL=(ALL) ALL\" > /etc/sudoers.d/wheel

    # Host Configuration
    echo \"\$hostname\" > /etc/hostname
    echo \"127.0.0.1  localhost\" > /etc/hosts
    echo \"::1        localhost\" >> /etc/hosts
    echo \"127.0.1.1  \$hostname.localdomain  \$hostname\" >> /etc/hosts

    # Bootloader
    pacman -S --noconfirm grub grub-btrfs efibootmgr os-prober
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    echo \"GRUB_DISABLE_OS_PROBER=false\" >> /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg

    # Reflector and pacman Setup
    sed -i '/^#Color$/c\Color' /etc/pacman.conf
    echo \"--save /etc/pacman.d/mirrorlist\" > /etc/xdg/reflector/reflector.conf
    echo \"--protocol https\" >> /etc/xdg/reflector/reflector.conf
    echo \"--country India\" >> /etc/xdg/reflector/reflector.conf
    echo \"--latest 10\" >> /etc/xdg/reflector/reflector.conf
    echo \"--age 24\" >> /etc/xdg/reflector/reflector.conf
    echo \"--sort rate\" >> /etc/xdg/reflector/reflector.conf
    systemctl enable reflector.timer

    # Services
    systemctl enable NetworkManager
    systemctl enable libvirtd
    virsh net-autostart default
    freshclam
    systemctl enable clamav-daemon.service

    pacman -Scc --noconfirm
"

umount -lR /mnt
echo "Reinstallation completed. Please reboot your system."
