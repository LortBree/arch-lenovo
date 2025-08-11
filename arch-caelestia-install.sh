#!/usr/bin/env bash
set -euo pipefail

echo "=== Arch Linux Automated Installer ==="

# --- Input dari user ---
read -rp "Masukkan hostname: " HOSTNAME
read -rp "Masukkan username: " USERNAME

echo "Masukkan password untuk root:"
passwd_root=""
while [ -z "$passwd_root" ]; do
  read -srp "Password root: " passwd_root
  echo
  read -srp "Konfirmasi password root: " passwd_root2
  echo
  [ "$passwd_root" = "$passwd_root2" ] || { echo "Password tidak cocok."; passwd_root=""; }
done

echo "Masukkan password untuk user $USERNAME:"
passwd_user=""
while [ -z "$passwd_user" ]; do
  read -srp "Password $USERNAME: " passwd_user
  echo
  read -srp "Konfirmasi password $USERNAME: " passwd_user2
  echo
  [ "$passwd_user" = "$passwd_user2" ] || { echo "Password tidak cocok."; passwd_user=""; }
done

# --- Format Partisi ---
echo "== Format Partisi =="
mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2
mkfs.ext4 /dev/sda3
mkfs.ext4 /dev/sda4

# --- Mount ---
echo "== Mounting Filesystems =="
mount /dev/sda3 /mnt
mkdir -p /mnt/{boot,home}
mount /dev/sda1 /mnt/boot
mount /dev/sda4 /mnt/home

# --- Install Base ---
echo "== Pasang Base System =="
pacstrap /mnt base linux linux-firmware git sudo

# --- Fstab ---
echo "== Generate fstab =="
genfstab -U /mnt >> /mnt/etc/fstab

# --- Chroot & Config ---
arch-chroot /mnt /bin/bash <<EOF
set -e

echo "== Setup Timezone & Clock =="
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
hwclock --systohc

echo "== Setup Locale =="
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "== Set Hostname & Hosts =="
echo "$HOSTNAME" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

echo "== Set Root Password =="
echo "root:$passwd_root" | chpasswd

echo "== Setup User $USERNAME =="
useradd -mG wheel "$USERNAME"
echo "$USERNAME:$passwd_user" | chpasswd
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/99_wheel

echo "== Install GRUB bootloader (UEFI) =="
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
grub-mkconfig -o /boot/grub/grub.cfg

echo "== Install Hyprland dan SDDM =="
pacman -S --noconfirm hyprland wayland sddm

echo "== Install SilentSDDM Theme (Rei) =="
cd /usr/share/sddm/themes
git clone https://github.com/uiriansan/SilentSDDM silent
ln -sfn silent /usr/share/sddm/themes/silent
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=silent" > /etc/sddm.conf.d/theme.conf

echo "== Clone & Install Caelestia Shell =="
cd /opt
git clone https://github.com/caelestia-dots/shell.git caelestia-shell
chown -R "$USERNAME":"$USERNAME" caelestia-shell

# Build beat_detector jika diperlukan
if [ -f caelestia-shell/assets/beat_detector.cpp ]; then
  g++ -std=c++17 -Wall -Wextra \
    -I/usr/include/pipewire-0.3 -I/usr/include/spa-0.2 -I/usr/include/aubio \
    -o beat_detector caelestia-shell/assets/beat_detector.cpp \
    -lpipewire-0.3 -laubio
  mkdir -p /usr/lib/caelestia
  mv beat_detector /usr/lib/caelestia/
fi

echo "== Aktifkan SDDM =="
systemctl enable sddm

EOF

echo "=== Instalasi selesai! Silakan reboot. ==="