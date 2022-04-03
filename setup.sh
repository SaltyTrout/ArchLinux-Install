#!/bin/bash

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