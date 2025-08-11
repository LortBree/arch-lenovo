#!/usr/bin/env bash
set -euo pipefail

# =================================================================================
# PERINGATAN KERAS!
# Skrip ini akan MENGHAPUS SEMUA DATA di /dev/sda.
# Skrip ini mengasumsikan partisi berikut TELAH DIBUAT SEBELUMNYA:
# /dev/sda1 : Partisi EFI (misal: 512M, tipe "EFI System")
# /dev/sda2 : Partisi Swap (misal: 4G atau lebih, tipe "Linux swap")
# /dev/sda3 : Partisi Root (/, misal: sisa ruang, tipe "Linux filesystem")
# /dev/sda4 : Partisi Home (/home, misal: sisa ruang, tipe "Linux filesystem")
#
# JANGAN JALANKAN SKRIP INI JIKA ANDA TIDAK YAKIN.
# =================================================================================

echo "=== Arch Linux Automated Installer (with Hyprland & Caelestia) ==="
echo "PERINGATAN: Skrip ini akan memformat /dev/sda1, /dev/sda2, /dev/sda3, dan /dev/sda4."
read -rp "Ketik 'YES' untuk melanjutkan: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo "Instalasi dibatalkan."
    exit 1
fi

# --- Input dari user ---
read -rp "Masukkan hostname: " HOSTNAME
read -rp "Masukkan username: " USERNAME

# --- Input Password (lebih aman dan bersih) ---
get_password() {
    local prompt_msg=$1
    local pass_var_name=$2
    local password=""
    local password2=""
    while true; do
        read -srp "$prompt_msg: " password
        echo
        read -srp "Konfirmasi password: " password2
        echo
        if [ "$password" = "$password2" ] && [ -n "$password" ]; then
            eval "$pass_var_name='$password'"
            break
        else
            echo "Password tidak cocok atau kosong. Silakan coba lagi."
        fi
    done
}

get_password "Masukkan password untuk root" ROOT_PASSWORD
get_password "Masukkan password untuk user $USERNAME" USER_PASSWORD

# --- Koneksi Internet ---
echo "== Memeriksa koneksi internet... =="
if ! ping -c 1 archlinux.org &>/dev/null; then
    echo "Error: Tidak ada koneksi internet. Silakan sambungkan ke internet terlebih dahulu."
    exit 1
fi

# --- Format Partisi ---
echo "== Memformat Partisi =="
mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
mkfs.ext4 /dev/sda3
mkfs.ext4 /dev/sda4

# --- Mount ---
echo "== Mounting Filesystems =="
mount /dev/sda3 /mnt
swapon /dev/sda2
mkdir -p /mnt/{boot,home}
mount /dev/sda1 /mnt/boot
mount /dev/sda4 /mnt/home

# --- Install Base System & Paket Penting ---
echo "== Memasang Base System dan Paket Penting =="
pacstrap /mnt base linux linux-firmware git sudo networkmanager

# --- Fstab ---
echo "== Generate fstab =="
genfstab -U /mnt >> /mnt/etc/fstab

# --- Chroot & Konfigurasi Sistem Baru ---
echo "== Konfigurasi Sistem di dalam Chroot =="
arch-chroot /mnt /bin/bash -c "
set -e

# Ekspor variabel agar bisa digunakan di dalam chroot
export HOSTNAME='$HOSTNAME'
export USERNAME='$USERNAME'
export ROOT_PASSWORD='$ROOT_PASSWORD'
export USER_PASSWORD='$USER_PASSWORD'

echo '== Setup Timezone & Clock =='
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
hwclock --systohc

echo '== Setup Locale =='
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo '== Set Hostname & Hosts =='
echo \"\$HOSTNAME\" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   \$HOSTNAME.localdomain \$HOSTNAME
HOSTS

echo '== Set Password Root =='
echo \"root:\$ROOT_PASSWORD\" | chpasswd

echo '== Setup User \$USERNAME =='
useradd -m -g users -G wheel \"\$USERNAME\"
echo \"\$USERNAME:\$USER_PASSWORD\" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/99_wheel

# --- Instalasi Paket Desktop (Hyprland, SDDM, Caelestia, dll) ---
echo '== Menginstall Paket Desktop dan Aplikasi Pendukung =='
pacman -S --noconfirm --needed \
    base-devel \
    grub efibootmgr \
    hyprland sddm xorg-xwayland \
    pipewire wireplumber pipewire-audio pipewire-pulse pipewire-jack \
    xdg-desktop-portal-hyprland \
    polkit-kde-agent \
    alacritty waybar wofi \
    thunar gvfs \
    swaybg swaylock mako grim slurp \
    ttf-jetbrains-mono-nerd noto-fonts-emoji \
    qt5-quickcontrols2 qt5-graphicaleffects \
    aubio bluez bluez-utils

echo '== Install GRUB bootloader (UEFI) =='
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
grub-mkconfig -o /boot/grub/grub.cfg

echo '== Membuat Hyprland dapat diakses dari SDDM =='
mkdir -p /usr/share/wayland-sessions
echo -e '[Desktop Entry]\nName=Hyprland\nComment=A dynamic tiling Wayland compositor\nExec=Hyprland\nType=Application' > /usr/share/wayland-sessions/hyprland.desktop

echo '== Install & Konfigurasi Tema SDDM (Silent) =='
git clone https://github.com/uiriansan/SilentSDDM /usr/share/sddm/themes/silent
mkdir -p /etc/sddm.conf.d
echo -e '[Theme]\nCurrent=silent' > /etc/sddm.conf.d/theme.conf

echo '== Clone & Setup Caelestia Shell =='
cd /home/\"\$USERNAME\"
# Clone repositori sebagai user, bukan di /opt
sudo -u \"\$USERNAME\" git clone https://github.com/caelestia-dots/shell.git .caelestia-src
# Pindahkan file konfigurasi ke lokasi yang benar
sudo -u \"\$USERNAME\" cp -rT .caelestia-src/hyprland .config/hyprland
sudo -u \"\$USERNAME\" cp -rT .caelestia-src/waybar .config/waybar
sudo -u \"\$USERNAME\" cp -rT .caelestia-src/alacritty .config/alacritty
sudo -u \"\$USERNAME\" cp -rT .caelestia-src/wofi .config/wofi
# Hapus folder sumber setelah disalin untuk kebersihan
rm -rf .caelestia-src

# Build beat_detector
if [ -f /home/\"\$USERNAME\"/.config/hyprland/assets/beat_detector.cpp ]; then
  echo '== Compiling beat_detector =='
  g++ -std=c++17 -Wall -Wextra \
    -I/usr/include/pipewire-0.3 -I/usr/include/spa-0.2 -I/usr/include/aubio \
    -o beat_detector /home/\"\$USERNAME\"/.config/hyprland/assets/beat_detector.cpp \
    -lpipewire-0.3 -laubio
  mkdir -p /usr/lib/caelestia
  mv beat_detector /usr/lib/caelestia/
fi

echo '== Mengaktifkan Layanan Penting (SDDM & NetworkManager) =='
systemctl enable sddm
systemctl enable NetworkManager
systemctl enable bluetooth.service
systemctl set-default graphical.target

" # Akhir dari Chroot

echo "======================================================"
echo "=== Instalasi Selesai! ==="
echo "Silakan unmount partisi dan reboot sistem Anda."
echo "Jalankan perintah berikut:"
echo "umount -R /mnt"
echo "reboot"
echo "======================================================"
