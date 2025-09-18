#!/bin/bash
# ==========================================================================
# Skrip Konfigurasi Dasar Arch Linux (Tanpa Install Paket)
# ==========================================================================
set -e

# --- Warna Output ---
C_RESET='\033[0m'; C_RED='\033[0;31m'; C_GREEN='\033[0;32m'; C_BLUE='\033[0;34m'
info() { echo -e "${C_BLUE}[INFO]${C_RESET} $1"; }
success() { echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; exit 1; }

# --- Pastikan Root ---
if [[ $(id -u) -ne 0 ]]; then
    error "Skrip ini harus dijalankan sebagai root!"
fi

# --- Input Data ---
read -p "Masukkan hostname: " hostname
read -p "Masukkan username baru: " username
read -sp "Masukkan password untuk user baru: " password
echo
read -sp "Masukkan password root: " rootpw
echo

# --- Hostname & Hosts ---
info "Mengatur hostname..."
echo "$hostname" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOF

# --- Timezone & Locale ---
info "Mengatur timezone dan locale..."
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
hwclock --systohc

# aktifkan locale en_US + id_ID (sesuai kebutuhan)
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/^#id_ID.UTF-8/id_ID.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# --- Buat User ---
info "Membuat user baru '$username'..."
useradd -m -G wheel -s /bin/bash "$username"
echo "$username:$password" | chpasswd

# --- Password Root ---
echo "root:$rootpw" | chpasswd

# --- Sudoers ---
info "Mengaktifkan sudo untuk grup wheel..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# --- Enable Service Dasar ---
info "Mengaktifkan NetworkManager..."
systemctl enable NetworkManager

success "Konfigurasi dasar selesai!"
echo "Reboot sistem lalu login sebagai user: $username"
