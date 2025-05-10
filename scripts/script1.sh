#!/bin/sh -e

# Constants
LANGCODE="en_US"         # Language code (e.g., en_US, de_DE)
MY_INIT="openrc"         # Init system: "openrc" or "dinit"
MY_DISK="/dev/sda"       # Disk to install to (e.g., /dev/sda)
SWAP_SIZE=4              # Swap size in GiB
MY_FS="btrfs"            # Filesystem: "btrfs" or "ext4"
ENCRYPTED="y"            # Encrypt root? "y" for yes, "n" for no
CRYPTPASS="password123"  # Encryption password (if ENCRYPTED="y")
REGION_CITY="America/Denver"  # Timezone (e.g., America/Denver)
MY_HOSTNAME="artix-host" # Hostname
ROOT_PASSWORD="root123"  # Root password

# Determine keymap
case "$LANGCODE" in
"en_GB")
    MY_KEYMAP="uk"
    ;;
"en_US")
    MY_KEYMAP="us"
    ;;
*)
    MY_KEYMAP=$(echo "$LANGCODE" | cut -c1-2)
    ;;
esac
sudo loadkeys "$MY_KEYMAP"

# Check boot mode
[ ! -d /sys/firmware/efi ] && printf "Not booted in UEFI mode. Aborting..." && exit 1

# Partition variables
PART1="$MY_DISK"1
PART2="$MY_DISK"2
case "$MY_DISK" in
*"nvme"* | *"mmcblk"*)
    PART1="$MY_DISK"p1
    PART2="$MY_DISK"p2
    ;;
esac

# Root partition
if [ "$ENCRYPTED" = "y" ]; then
    MY_ROOT="/dev/mapper/root"
else
    MY_ROOT=$PART2
fi

# Packages
pkgs="base base-devel $MY_INIT elogind-$MY_INIT efibootmgr grub dhcpcd wpa_supplicant connman-$MY_INIT"
[ "$MY_FS" = "btrfs" ] && pkgs="$pkgs btrfs-progs"
[ "$ENCRYPTED" = "y" ] && pkgs="$pkgs cryptsetup cryptsetup-$MY_INIT"

# Partition disk
printf "label: gpt\n,550M,U\n,,\n" | sfdisk "$MY_DISK"

# Format and mount partitions
if [ "$ENCRYPTED" = "y" ]; then
    yes "$CRYPTPASS" | cryptsetup -q luksFormat "$PART2"
    yes "$CRYPTPASS" | cryptsetup open "$PART2" root
fi

mkfs.fat -F 32 "$PART1"

if [ "$MY_FS" = "ext4" ]; then
    yes | mkfs.ext4 "$MY_ROOT"
    mount "$MY_ROOT" /mnt

    # Create swapfile
    mkdir /mnt/swap
    fallocate -l "$SWAP_SIZE"G /mnt/swap/swapfile
    chmod 600 /mnt/swap/swapfile
    mkswap /mnt/swap/swapfile
elif [ "$MY_FS" = "btrfs" ]; then
    mkfs.btrfs -f "$MY_ROOT"

    # Create subvolumes
    mount "$MY_ROOT" /mnt
    btrfs subvolume create /mnt/root
    btrfs subvolume create /mnt/home
    btrfs subvolume create /mnt/swap
    umount -R /mnt

    # Mount subvolumes
    mount -t btrfs -o compress=zstd,subvol=root "$MY_ROOT" /mnt
    mkdir /mnt/home
    mkdir /mnt/swap
    mount -t btrfs -o compress=zstd,subvol=home "$MY_ROOT" /mnt/home
    mount -t btrfs -o noatime,nodatacow,subvol=swap "$MY_ROOT" /mnt/swap

    # Create swapfile
    btrfs filesystem mkswapfile -s "$SWAP_SIZE"G /mnt/swap/swapfile
fi

swapon /mnt/swap/swapfile

mkdir /mnt/boot
mount "$PART1" /mnt/boot

case $(grep vendor /proc/cpuinfo) in
*"Intel"*)
    pkgs="$pkgs intel-ucode"
    ;;
*"Amd"*)
    pkgs="$pkgs amd-ucode"
    ;;
esac

unset --
IFS=" "
for pkg in $pkgs; do
    set -- "$@" "$pkg"
done

# Install base system and kernel
basestrap /mnt "$@"
basestrap /mnt linux linux-firmware linux-headers mkinitcpio
fstabgen -U /mnt >/mnt/etc/fstab

# Chroot configuration
ln -sf /usr/share/zoneinfo/"$REGION_CITY" /etc/localtime
hwclock --systohc

# Localization
printf "%s.UTF-8 UTF-8\n" "$LANGCODE" >>/etc/locale.gen
locale-gen
printf "LANG=%s.UTF-8\n" "$LANGCODE" >/etc/locale.conf
printf "KEYMAP=%s\n" "$MY_KEYMAP" >/etc/vconsole.conf

# Host setup
printf '%s\n' "$MY_HOSTNAME" >/etc/hostname
[ "$MY_INIT" = "openrc" ] && printf 'hostname="%s"\n' "$MY_HOSTNAME" >/etc/conf.d/hostname
printf "\n127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t%s.localdomain\t%s\n" "$MY_HOSTNAME" "$MY_HOSTNAME" >/etc/hosts

# Install boot loader
root_uuid=$(blkid "$PART2" -o value -s UUID)
if [ "$ENCRYPTED" = "y" ]; then
    my_params="cryptdevice=UUID=$root_uuid:root root=/dev/mapper/root"
fi
sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT.*$/GRUB_CMDLINE_LINUX_DEFAULT=\"$my_params\"/g" /etc/default/grub
[ "$ENCRYPTED" = "y" ] && sed -i '/GRUB_ENABLE_CRYPTODISK=y/s/^#//g' /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot --recheck
grub-install --target=x86_64-efi --efi-directory=/boot --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Root user
yes "$ROOT_PASSWORD" | passwd

sed -i '/%wheel ALL=(ALL) ALL/s/^#//g' /etc/sudoers

# Init system setup
if [ "$MY_INIT" = "openrc" ]; then
    sed -i '/rc_need="localmount"/s/^#//g' /etc/conf.d/swap
    rc-update add connmand default
elif [ "$MY_INIT" = "dinit" ]; then
    ln -s /etc/dinit.d/connmand /etc/dinit.d/boot.d/
fi

# Configure mkinitcpio
[ "$MY_FS" = "btrfs" ] && sed -i 's/BINARIES=()/BINARIES=(\/usr\/bin\/btrfs)/g' /etc/mkinitcpio.conf
if [ "$ENCRYPTED" = "y" ]; then
    sed -i 's/^HOOKS.*$/HOOKS=(base udev autodetect keyboard keymap modconf block encrypt filesystems fsck)/g' /etc/mkinitcpio.conf
else
    sed -i 's/^HOOKS.*$/HOOKS=(base udev autodetect keyboard keymap modconf block filesystems fsck)/g' /etc/mkinitcpio.conf
fi
mkinitcpio -P

printf '\nYou may now poweroff.\n'
