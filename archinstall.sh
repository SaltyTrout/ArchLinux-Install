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
sgdisk -n 1::+550M --typecode=2:ef00 --change-name=2:'EFIBOOT' ${device} # partition 1 (UEFI Boot Partition)
sgdisk -n 2::-0 --typecode=3:8300 --change-name=3:'ROOT' ${device} # partition 2 (Root), default start, remaining
partprobe ${device}

echo -n "Format and mount partitions"
partition1=${device}1
partition2=${device}2

mkfs.vfat -F32 -n "EFIBOOT" ${partition1}
mkfs.ext4 -L ROOT ${partition2}
mount -t ext4 ${partition2} /mnt

mkdir /mnt/boot/efi
mount ${partition1} /mnt/boot/efi

echo -n 'Setup mirrors'
pacman -Syy
pacman -S reflector
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

arch-chroot /mnt

ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc

sed -i '/en_US.UTF-8/s/^/#/g' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
export LANG=en_US.UTF-8

echo ${hostname} >> /etc/hostname
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1    localhost" >> /etc/hosts
echo "127.0.1.1    ${hostname}" >> /etc/hosts

echo "root:${rootPassword}" | chpasswd -R /mnt

useradd -m -G wheel,audio,video -s /bin/bash ${user}
echo "${user}:${userPassword}" | chpasswd

pacman -S sudo --noconfirm --needed
# Remove no password sudo rights
sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
# Add sudo rights
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Install and configure grub bootloader
pacman -S grub efibootmgr dosfstools os-prober mtools intel-ucode
grub-install --target=x86_64-efi --efi-directory=/efi/ --bootloader-id=Arch --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Install additional packages
pacman -S iwd wpa_supplicant dialog dhcpcd ifplugd

echo -ne "
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=systemd
" > /etc/iwd/main.conf

echo -ne "
-------------------------------------------------------------------------
                    Automated Arch Linux Installer
-------------------------------------------------------------------------
                Done - Please Eject Install Media and Reboot
"