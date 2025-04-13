#!/bin/bash
set -euo pipefail

# Disk Selection
echo "Available disks:"
lsblk
echo ""
echo ""
read -p "Enter Disk: " disk
disk="/dev/${disk%/}"

# Partitioning
parted -s "$disk" mklabel gpt

# Convert swap size to MiB
swap="8"
swap_mib=$((swap * 1024))

# Partition Layout
parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
parted -s "$disk" set 1 esp on
parted -s "$disk" mkpart primary linux-swap 1025MiB $((1025 + swap_mib))MiB
parted -s "$disk" mkpart primary ext4 $((1025 + swap_mib))MiB 100%

# Formatting
mkfs.fat -F32 -n BOOT "${disk}1"
mkswap -L SWAP "${disk}2"
mkfs.ext4 -L ROOT "${disk}3"

# Mounting
mount "${disk}3" /mnt
mkdir -p /mnt/boot
mount "${disk}1" /mnt/boot
swapon "${disk}2"

# Base Installation
install_pkgs=(
base base-devel linux linux-firmware libxkbcommon-x11 sudo man-db man-pages 
openssh gzip ncdu htop stow fastfetch bat eza fd fzf git ripgrep ripgrep-all sqlite ntfs-3g exfat-utils mtools dosfstools 
networkmanager ufw newsboat pipewire wireplumber pipewire-pulse mpv 
xorg-xwayland xdg-desktop-portal-wlr xdg-desktop-portal-gtk sway swaybg swayimg swaylock swayidle foot mako fuzzel 
papirus-icon-theme noto-fonts noto-fonts-cjk noto-fonts-emoji clang lua python go git ttc-iosevka ttf-iosevkaterm-nerd 
neovim tmux zathura texlive-latex texlive-bin unzip unrar zip grim slurp pcmanfm gimp clamav polkit intel-ucode 
wl-clipboard cliphist libnotify asciinema mako qemu-full libvirt virt-manager yt-dlp reflector
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

    echo ""
    echo ""
    echo \"Root passwd\"
    passwd
    echo ""
    echo ""

    # User Setup
    read -p \"Username: \" user
    useradd -m -G wheel,storage,power,video,audio -s /bin/bash \"\$user\"
    echo ""
    echo ""
    echo \"\$user passwd\"
    passwd \"\$user\"
    echo ""
    echo ""

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
    pacman -S --noconfirm grub efibootmgr os-prober
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    echo \"GRUB_DISABLE_OS_PROBER=false\" >> /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg

    # Reflector Setup
    mkdir /etc/xdg/reflector
    echo \"--save /etc/pacman.d/mirrorlist\" > /etc/xdg/reflector/reflector.conf
    echo \"--protocol https\" >> /etc/xdg/reflector/reflector.conf
    echo \"--country India\" >> /etc/xdg/reflector/reflector.conf
    echo \"--latest 10\" >> /etc/xdg/reflector/reflector.conf
    echo \"--age 24\" >> /etc/xdg/reflector/reflector.conf
    echo \"--sort rate\" >> /etc/xdg/reflector/reflector.conf
    systemctl enable reflector.timer

    # Copy config
    cd /home/piyush
    git clone https://github.com/zedonix/arch.git
    git clone https://github.com/tmux-plugins/tpm /home/piyush/.tmux/plugins/tpm
    cd arch
    mkdir /home/piyush/.config
    cp -r config/* /home/piyush/.config/
    cp .bashrc /home/piyush/.bashrc

    # Change ownership to the piyush user
    chown -R piyush:piyush /home/piyush/.config
    chown -R piyush:piyush /home/piyush/.tmux
    chown -R piyush:piyush /home/piyush/arch
    chown piyush:piyush /home/piyush/.bashrc

    # Services
    systemctl enable NetworkManager

    freshclam
    systemctl enable clamav-daemon.service

    # Clean up package cache and Wrapping up
    pacman -Syu
    pacman -Scc --noconfirm
"

# Unmount and finalize
umount -lR /mnt
echo "Installation completed. Please reboot your system."
