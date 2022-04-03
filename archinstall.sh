#!/bin/bash
set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

# Setup Wireless
echo -n "Setting up Wireless"
iwctl

ping -c 3 google.com


exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")

echo -n ""
echo -n "Root Password: "
read rootPassword
: "${rootPassword:?"Missing root password"}"

echo -n ""
echo -n "Hostname: "
read hostname
: "${hostname:?"Missing hostname"}"

echo -n ""
echo -n "User: "
read user
: "${user:?"Missing user name"}"

echo -n ""
echo -n "User Password: "
read userPassword
: "${userPassword:?"Missing user password"}"

echo -n ""
echo -n "Installation Disk: "
read device
: "${device:?"Missing installation device"}"

echo -n 'Setting time'
timedatectl set-ntp true
timedatectl set-timezone America/New_York

echo -n 'Setup partitions'
sgdisk -Z ${device} # zap all on disk
sgdisk -a 2048 -o ${device} # new gpt disk 2048 alignment
sgdisk -n 1::+550M --typecode=1:ef00 --change-name=1:'EFIBOOT' ${device} # partition 1 (UEFI Boot Partition)
sgdisk -n 2::-0 --typecode=2:8300 --change-name=2:'ROOT' ${device} # partition 2 (Root), default start, remaining
partprobe ${device}

echo -n "Format and mount partitions"
partition1=${device}1
partition2=${device}2

mkfs.vfat -F32 ${partition1}
mkfs.ext4 ${partition2}
mount ${partition2} /mnt

mkdir -p /mnt/boot/efi
mount ${partition1} /mnt/boot/efi

echo -n 'Setup mirrors'
pacman -Syy
pacman -S reflector  --noconfirm --needed
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector -c "US" -f 12 -l 10 -n 12 --save /etc/pacman.d/mirrorlist

echo -n 'Installing Arch'
pacstrap /mnt base linux linux-firmware base-devel vim nano --noconfirm --needed

echo -n 'Generating FSTAB'
genfstab -U /mnt >> /mnt/etc/fstab
echo " 
  Generated /etc/fstab:
"
cat /mnt/etc/fstab

arch-chroot /mnt setup.sh