#!/usr/bin/env bash

# ------------------ Configurable Constants ------------------
KEYMAP="us"
TIMEZONE="Europe/London"
LOCALE="en_US.UTF-8 UTF-8"
LANG="LANG=en_US.UTF-8"
HOSTNAME="artix"
SWAP_SIZE_GB=2
WIPE_DISK=true  # Set to false to preserve existing partitions
USE_IPV6_PRIVACY=true

# Core packages
BASE_PKGS="base openrc elogind-openrc linux linux-firmware git man-db iptables-nft"
DEV_PKGS="base-devel bc"
EXTRA_PKGS="networkmanager-openrc grub efibootmgr os-prober mtools dosfstools fastfetch htop neovim"

# ------------------ Setup ------------------
loadkeys "$KEYMAP"
echo "=== Minimal Artix Installer ==="

fdisk -l
read -rp "Target disk (e.g. /dev/sda): " disk
read -rp "Continue and install to $disk? This will DESTROY DATA. (y/N): " confirm
[[ "${confirm,,}" != "y" ]] && exit 1

read -rp "New username: " username
read -rsp "Password for $username: " userpassword; echo

# Normalize values
username="${username,,}"
HOSTNAME="${HOSTNAME,,}"
disk0="$disk"
[[ "$disk" =~ nvme0n|mmcblk ]] && disk="${disk}p"

# Detect boot mode
boot=legacy
[ -d /sys/firmware/efi ] && boot=uefi

# ------------------ Partitioning ------------------
if [ "$WIPE_DISK" = true ]; then
    wipefs --all --force "$disk0"
    if [ "$boot" = "uefi" ]; then
        echo -e "g\nn\n1\n\n+256M\nt\n1\nn\n\n\n\nw" | fdisk "$disk0"
    else
        echo -e "o\nn\np\n\n\n\nw" | fdisk "$disk0"
    fi
fi

# Wait for partition table to settle
sleep 2

# Determine partitions
if [ "$boot" = "uefi" ]; then
    EFI="${disk}1"
    ROOT="${disk}2"
    mkfs.fat -F32 "$EFI"
    mkfs.ext4 -O fast_commit "$ROOT"
    mount "$ROOT" /mnt
    mkdir -p /mnt/boot/EFI
    mount "$EFI" /mnt/boot/EFI
else
    ROOT="${disk}1"
    mkfs.ext4 -O fast_commit "$ROOT"
    mount "$ROOT" /mnt
fi

# ------------------ Swap ------------------
if [ "$SWAP_SIZE_GB" -gt 0 ]; then
    dd if=/dev/zero of=/mnt/swapfile bs=1G count="$SWAP_SIZE_GB" status=progress
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
fi

# ------------------ Pre-config ------------------
echo "$HOSTNAME" > /mnt/etc/hostname
echo "hostname=\"$HOSTNAME\"" > /mnt/etc/conf.d/hostname
echo "$LOCALE" > /mnt/etc/locale.gen
echo "$LANG" > /mnt/etc/locale.conf
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /mnt/etc/localtime

# ------------------ Install ------------------
pacman -Sy --noconfirm
basestrap /mnt $BASE_PKGS $DEV_PKGS $EXTRA_PKGS
fstabgen -U /mnt >> /mnt/etc/fstab

# Basic sysctl
mkdir -p /mnt/etc/sysctl.d
echo "vm.swappiness=$((SWAP_SIZE_GB > 0 ? 10 : 0))" > /mnt/etc/sysctl.d/99-swap.conf
echo "kernel.sysrq=244" > /mnt/etc/sysctl.d/35-sysrq.conf
if [ "$USE_IPV6_PRIVACY" = true ]; then
    echo 'net.ipv6.conf.all.use_tempaddr = 2' > /mnt/etc/sysctl.d/40-ipv6.conf
    for iface in /sys/class/net/*; do
        echo "net.ipv6.conf.${iface##*/}.use_tempaddr = 2" >> /mnt/etc/sysctl.d/40-ipv6.conf
    done
fi

# ------------------ Chroot Setup ------------------
arch-chroot /mnt /bin/bash <<EOF
locale-gen
hwclock --systohc

rc-update add NetworkManager default

if [ "$boot" = "uefi" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=GRUB
else
    grub-install --target=i386-pc "$disk0"
fi
grub-mkconfig -o /boot/grub/grub.cfg

useradd -m -G wheel "$username"
echo "$username:$userpassword" | chpasswd

echo "permit persist :wheel" > /etc/doas.conf
ln -s /usr/bin/doas /usr/local/bin/sudo

rc-update add local default
EOF

# ------------------ Done ------------------
echo "✅ Artix installation complete. You can now reboot."
