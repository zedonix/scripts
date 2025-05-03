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

if [[ "$disk" == *nvme* ]]; then
  part1="${disk}p1"
  part2="${disk}p2"
  part3="${disk}p3"
else
  part1="${disk}1"
  part2="${disk}2"
  part3="${disk}3"
fi

# Partitioning
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
swapon "$part2"
mkfs.btrfs -f -L ROOT "$part3"

# Mounting
mount "$part3" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var

umount /mnt

mount -o noatime,compress=zstd,subvol=@ "${disk}3" /mnt
mkdir -p /mnt/{boot,home,var}
mount -o noatime,compress=zstd,subvol=@home "${disk}3" /mnt/home
mount -o noatime,compress=zstd,subvol=@var "${disk}3" /mnt/var

mkdir -p /mnt/boot
mount "${disk}1" /mnt/boot

# Base Installation
install_pkgs=(
    base base-devel linux linux-headers linux-firmware libxkbcommon-x11 sudo man-db man-pages snapper btrfs-progs
    openssh ncdu htop fastfetch bat eza fzf git ripgrep ripgrep-all sqlite ntfs-3g exfat-utils mtools dosfstools qemu-desktop virt-manager
    networkmanager ufw newsboat pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-audio pipewire-jack mpv sassc libvirt dnsmasq vde2
    xorg-xwayland xdg-desktop-portal-wlr xdg-desktop-portal-gtk sway swaybg swayimg swaylock swayidle foot wl-clip-persist swaync fuzzel autotiling
    papirus-icon-theme noto-fonts noto-fonts-cjk noto-fonts-emoji ttc-iosevka ttf-iosevkaterm-nerd yt-dlp aria2 vivaldi bridge-utils openbsd-netcat
    neovim tmux zathura texlive-latex unrar 7zip rsync grim slurp flameshot pcmanfm-gtk3 gimp clamav intel-ucode inotify-tools easyeffects
    wl-clipboard cliphist libnotify asciinema reflector polkit polkit-gnome lua python python-black stylua pyright
)

# Rate and install the base system
reflector --country 'India' --latest 10 --age 24 --sort rate --save /etc/pacman.d/mirrorlist

pacstrap /mnt "${install_pkgs[@]}"

# System Configuration
genfstab -U /mnt >> /mnt/etc/fstab

# Run commands in the chroot
arch-chroot /mnt /bin/bash -c "
    # Configuration
    timezone=\"Asia/Kolkata\"
    hostname=\"archlinux\"

    echo \"Setting root password...\"
    passwd

    # User Setup
    read -p \"Username: \" user
    useradd -m -G wheel,storage,power,video,audio,libvirt -s /bin/bash \"\$user\"
    echo \"Setting user password...\"
    passwd \"\$user\"

    # Local Setup
    ln -sf \"/usr/share/zoneinfo/\$timezone\" /etc/localtime
    hwclock --systohc
    sed -i \"/en_US.UTF-8/s/^#//\" /etc/locale.gen
    locale-gen
    echo \"LANG=en_US.UTF-8\" > /etc/locale.conf
    timedatectl set-ntp true

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

    # Copy config
    sudo -u \"\$user\" bash -c '
        mkdir -p \"/home/\${USER}/Downloads\"
        mkdir -p \"/home/\${USER}/Documents\"
        mkdir -p \"/home/\${USER}/Public\"
        mkdir -p \"/home/\${USER}/Templates\"
        mkdir -p \"/home/\${USER}/Videos\"
        mkdir -p \"/home/\${USER}/Pictures/Screenshots\"
        mkdir -p \"/home/\${USER}/PenDrive\"

        git clone https://github.com/zedonix/scripts.git \"/home/\${USER}/.scripts\"
        git clone https://github.com/zedonix/dotfiles.git \"/home/\${USER}/.dotfiles\"
        git clone https://github.com/zedonix/GruvboxGtk.git \"/home/\${USER}/Downloads/GruvboxGtk\"
        git clone https://github.com/tmux-plugins/tpm \"/home/\${USER}/.tmux/plugins/tpm\"

        mkdir -p \"/home/\${USER}/.config\"
        ln -sf \"/home/\${USER}/.dotfiles/.bashrc\" \"/home/\${USER}/.bashrc\"

        links=(
            foot
            fuzzel
            htop
            newsboat
            nvim
            sway
            tmux
            zathura
            swaync
            mako
        )
        rm \"/home/\${USER}/dotfiles/.config/nvim/lazy-lock.json\"
        for link in \"\${links[@]}\"; do
            ln -s \"/home/\${USER}/.dotfiles/.config/\$link/\" \"/home/\${USER}/.config\"
        done
    '

    # Services
    systemctl enable NetworkManager
    systemctl enable libvirtd
    virsh net-autostart default
    freshclam
    systemctl enable clamav-daemon.service

    # Clean up package cache and Wrapping up
    pacman -Scc --noconfirm
"

# Unmount and finalize
umount -lR /mnt
echo "Installation completed. Please reboot your system."
