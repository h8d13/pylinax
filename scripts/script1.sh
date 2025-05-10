#!/usr/bin/env bash

# === CONSTANTS ===
KEYMAP="us"
BASE_DEVEL_PKGS="db diffutils gc guile libisl libmpc perl autoconf automake bash dash binutils bison esysusers etmpfiles fakeroot file findutils flex gawk gcc gettext grep groff gzip libtool m4 make pacman pacman-contrib patch pkgconf sed opendoas texinfo which bc udev ntp"
KERNEL_PKGS="linux linux-firmware"
NETWORK_PKG="networkmanager-openrc"
BOOTLOADER_PKGS="grub efibootmgr os-prober mtools dosfstools"
DEFAULT_LANG="en_US.UTF-8"

# === INITIAL SETUP ===
loadkeys "$KEYMAP"
echo "--------------------------------------------------------------"
echo "Artix Base Installer (Simplified)"
echo "Last updated: 2025-04-06"
echo "--------------------------------------------------------------"
read -n 1 -s -r -p "Press any key to begin..."

# === BASIC QUESTIONS ===
echo -e "\nChoose Form Factor:\n1. Laptop\n2. Desktop\n3. Headless"
read -rp "Formfactor: " formfactor

fdisk -l
read -rp "Target Disk: " disk
read -rp "Swap Size (in GB): " swap
read -n 1 -rp "Wipe Disk? (y/N): " wipe
echo
read -rp "Username: " username
read -rp "Password for $username: " userpassword
read -rp "Hostname: " hostname

# === TIMEZONE CONFIG ===
zroot=/usr/share/zoneinfo
while true; do
    echo "Available Timezones:"
    ls "$zroot"
    read -rp "Timezone (Region/City): " timezone
    if [ -f "$zroot/$timezone" ]; then
        break
    else
        echo "Invalid timezone. Try again."
    fi
done

# === SYSTEM DETECTION ===
pacman -Sy --noconfirm bc
threadsminusone=$(echo "$(nproc) - 1" | bc)

# UEFI or BIOS?
if [ -d "/sys/firmware/efi" ]; then
    boot=1
else
    boot=2
fi

# === VARIABLE NORMALIZATION ===
wipe=$(echo "$wipe" | tr '[:upper:]' '[:lower:]')
username=$(echo "$username" | tr '[:upper:]' '[:lower:]')
hostname=$(echo "$hostname" | tr '[:upper:]' '[:lower:]')

disk0=$disk
if [[ "$disk" == /dev/nvme0n* || "$disk" == /dev/mmcblk* ]]; then
    disk="$disk"'p'
fi

# === PARTITIONING ===
if [ "$boot" == 1 ]; then
    # UEFI system partitioning
    if [ "$wipe" == "y" ]; then
        wipefs --all --force "$disk0"
        # Create GPT partition table, EFI partition, and root partition
        echo -e "g\nn\n\n\n+256M\nEF00\nn\n\n\n\nw" | fdisk "$disk0"
    fi
    mkfs.fat -F32 "${disk}1"  # EFI partition
    mkfs.ext4 "${disk}2"       # Root partition
    mount "${disk}2" /mnt      # Mount root partition
    mkdir -p /mnt/boot/EFI
    mount "${disk}1" /mnt/boot/EFI  # Mount EFI partition
else
    # BIOS system partitioning
    if [ "$wipe" == "y" ]; then
        wipefs --all --force "$disk0"
        # Create MBR partition table and root partition
        echo -e "o\nn\np\n\n\nw" | fdisk "$disk0"
    fi
    mkfs.ext4 "${disk}1"       # Root partition
    mount "${disk}1" /mnt      # Mount root partition
fi

# === SWAP SETUP ===
if [ "$swap" -gt 0 ]; then
    dd if=/dev/zero of=/mnt/swapfile bs=1G count="$swap" status=progress
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
fi

# === SYSTEM CONFIG ===
echo "$hostname" > /mnt/etc/hostname
echo "127.0.0.1 localhost" > /mnt/etc/hosts
mkdir -p /mnt/etc/conf.d
echo "hostname=\"$hostname\"" > /mnt/etc/conf.d/hostname
ln -sf "/usr/share/zoneinfo/$timezone" /mnt/etc/localtime
echo "$DEFAULT_LANG UTF-8" > /mnt/etc/locale.gen
echo "LANG=$DEFAULT_LANG" > /mnt/etc/locale.conf

# === INSTALL BASE SYSTEM ===
fstabgen -U /mnt >> /mnt/etc/fstab
basestrap /mnt base $BASE_DEVEL_PKGS $KERNEL_PKGS openrc elogind-openrc git man-db iptables-nft

# === NETWORKING ===
basestrap /mnt $NETWORK_PKG
artix-chroot /mnt rc-update add NetworkManager

# === USER SETUP ===
artix-chroot /mnt groupadd libvirt
artix-chroot /mnt useradd -m -g users -G wheel,uucp,libvirt "$username"
echo "$username:$userpassword" | artix-chroot /mnt chpasswd
echo "permit persist keepenv :wheel as root" > /mnt/etc/doas.conf
ln -s /usr/bin/doas /mnt/usr/local/bin/sudo

# === LOCALE & TIME ===
artix-chroot /mnt locale-gen

# === BOOTLOADER INSTALL ===
basestrap /mnt $BOOTLOADER_PKGS
if [ "$boot" == 1 ]; then
    artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=GRUB
else
    artix-chroot /mnt grub-install --target=i386-pc "$disk0"
fi
artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# === SYSCTL TUNING ===
echo 'kernel.sysrq = 244' > /mnt/etc/sysctl.d/35-sysrq.conf
echo -e 'net.ipv6.conf.all.use_tempaddr = 2\nnet.ipv6.conf.default.use_tempaddr = 2' > /mnt/etc/sysctl.d/40-ipv6.conf

if [ "$swap" -gt 0 ]; then
    echo 'vm.swappiness=10' > /mnt/etc/sysctl.d/99-swappiness.conf
else
    echo 'vm.swappiness=0' > /mnt/etc/sysctl.d/99-swappiness.conf
fi

# === FINALIZATION ===
artix-chroot /mnt rc-update add local
echo -e "\nInstallation complete!"
echo "You may now power off, remove installation media, and reboot into your new system."
