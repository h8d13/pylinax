#!/usr/bin/env bash

# ------------------ Configuration ------------------
LOCALE="en_US.UTF-8 UTF-8"
LANG="LANG=en_US.UTF-8"
TIMEZONE="Europe/London"
HOSTNAME="artix"
SWAP_SIZE_GB=2
PACKAGES="base base-devel openrc elogind-openrc linux linux-firmware git man-db iptables-nft bc udev ntp networkmanager-openrc grub efibootmgr os-prober mtools dosfstools"

# ------------------ User Input ------------------
loadkeys us
clear
echo "Available Disks:"
lsblk -d -e7 -o NAME,SIZE,MODEL
read -rp "Target disk (e.g., /dev/sda): " DISK
read -rp "Confirm you want to format $DISK (yes/NO): " CONFIRM
[[ "$CONFIRM" != "yes" ]] && echo "Aborted." && exit 1
read -rp "Username: " USERNAME
read -rsp "User password: " USERPASS
echo
read -rsp "Root password: " ROOTPASS
echo

# ------------------ Partitioning ------------------
fdisk "$DISK" <<EOF
g
n


+512M
t
1
n


+${SWAP_SIZE_GB}G
t
2
n


+100%
t
3
w
EOF

sleep 2

EFI_PART="${DISK}1"
SWAP_PART="${DISK}2"
ROOT_PART="${DISK}3"

mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 -O fast_commit "$ROOT_PART"
mkswap "$SWAP_PART"
swapon "$SWAP_PART"

mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot/EFI
mount "$EFI_PART" /mnt/boot/EFI

# ------------------ Swap File ------------------
if [ "$SWAP_SIZE_GB" -gt 0 ]; then
    dd if=/dev/zero of=/mnt/swapfile bs=1G count="$SWAP_SIZE_GB" status=progress
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
fi

# ------------------ FSTAB ------------------
fstabgen -U /mnt >> /mnt/etc/fstab

# ------------------ Pre-chroot Configuration ------------------
echo "$LOCALE" > /mnt/etc/locale.gen
echo "$LANG" > /mnt/etc/locale.conf
echo "$TIMEZONE" > /mnt/etc/timezone
echo "$HOSTNAME" > /mnt/etc/hostname
echo "hostname=\"$HOSTNAME\"" > /mnt/etc/conf.d/hostname

# ------------------ Base Installation ------------------
basestrap /mnt $PACKAGES

# ------------------ Chroot Configuration ------------------
cat <<EOF | artix-chroot /mnt /bin/bash

# Timezone and Locale
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
locale-gen
hwclock --systohc

# Enable NetworkManager
rc-update add NetworkManager default

# Set Root Password
echo "root:$ROOTPASS" | chpasswd

# User Setup
useradd -m -g users -G wheel,uucp "$USERNAME"
echo "$USERNAME:$USERPASS" | chpasswd

# Basic sudo-like setup using doas
pacman -S opendoas --noconfirm
echo "permit persist :wheel" > /etc/doas.conf
ln -sf /usr/bin/doas /usr/local/bin/sudo

# Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=GRUB --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Swap tuning
if [ "$SWAP_SIZE_GB" -gt 0 ]; then
    echo 'vm.swappiness=10' > /etc/sysctl.d/99-swappiness.conf
else
    echo 'vm.swappiness=0' > /etc/sysctl.d/99-swappiness.conf
fi

# Trim, hostname and other minimal settings
echo 'kernel.sysrq = 244' > /etc/sysctl.d/35-sysrq.conf
echo -e "#!/bin/sh\nfstrim -Av &" > /etc/local.d/99-trim.start
chmod +x /etc/local.d/99-trim.start
rc-update add local

EOF

# ------------------ Final Message ------------------
echo -e "\n---------------------------------------------------"
echo "Installation complete! You may now power off."
echo "Remove the install media before rebooting."
echo "---------------------------------------------------"
