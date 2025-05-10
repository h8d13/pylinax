#!/usr/bin/env bash

# Constants
KEYBOARD_LAYOUT="us"
DISK="/dev/sda"
SWAP_SIZE_GB=4
USERNAME="artixuser"
USER_PASSWORD="password123"
HOSTNAME="artix-host"
TIMEZONE="America/New_York"

# Set keyboard layout
loadkeys $KEYBOARD_LAYOUT
echo "Starting simplified Artix Install Script..."

# Disk partitioning and formatting
if [ "$WIPE_DISK" = true ]; then
    wipefs --all --force "$DISK"
    echo "g
    n
    1

    +256M
    t
    1
    n



    w
    " | fdisk -w always -W always "$DISK"
fi

# Disk formatting
mkfs.fat -F32 "${DISK}1"
mkfs.ext4 -O fast_commit "${DISK}2"

# Mount partitions
mount "${DISK}2" /mnt
mkdir -p /mnt/{boot/EFI,etc/conf.d}
mount "${DISK}1" /mnt/boot/EFI

# Swap file creation
if [ "$SWAP_SIZE_GB" -gt 0 ]; then
    dd if=/dev/zero of=/mnt/swapfile bs=1G count="$SWAP_SIZE_GB" status=progress
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
fi

# Generate fstab
fstabgen -U /mnt >> /mnt/etc/fstab

# Set hostname
echo "$HOSTNAME" > /mnt/etc/hostname

# Install base packages
BASE_DEVEL='db diffutils gc guile libisl libmpc perl autoconf automake bash dash binutils bison esysusers etmpfiles fakeroot file findutils flex gawk gcc gettext grep groff gzip libtool m4 make'
basestrap /mnt base $BASE_DEVEL openrc elogind-openrc linux linux-firmware git man-db iptables-nft

# Set timezone
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /mnt/etc/localtime

# Set username and password
echo "$USERNAME:$USER_PASSWORD" | chpasswd --root /mnt

echo "Simplified installation completed. Reboot to use your new system."
