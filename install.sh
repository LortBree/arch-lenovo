#!/bin/bash

# ==============================================================================
# Skrip Instalasi Hyprland Mandiri (Mode Root) - Versi 2.1
#
# Deskripsi:
# Dirancang untuk dijalankan pada instalasi Arch Linux yang BARU sebagai ROOT.
# Skrip ini mengotomatiskan pembuatan pengguna baru dan penyiapan lingkungan
# desktop Hyprland yang lengkap, stabil, dan mandiri untuk pengguna tersebut.
#
# Peringatan:
# - HANYA jalankan pada instalasi Arch Linux yang bersih sebagai pengguna ROOT.
# - Diperlukan koneksi internet.
# ==============================================================================

# --- Konfigurasi Warna dan Fungsi Logging ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[0;33m'

info() { echo -e "${C_BLUE}[INFO]${C_RESET} $1"; }
success() { echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"; }
warn() { echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; exit 1; }

# --- Fase 0: Pemeriksaan Pra-Instalasi ---
pre_flight_checks() {
    info "Memulai pemeriksaan pra-instalasi..."

    if [[ $(id -u) -ne 0 ]]; then
        error "Skrip ini harus dijalankan sebagai root. Gunakan 'sudo ./nama_skrip.sh'."
    fi

    if ! ping -c 1 -W 1 archlinux.org &> /dev/null; then
        error "Tidak ada koneksi internet. Harap sambungkan dan coba lagi."
    fi
    
    success "Pemeriksaan pra-instalasi selesai."
}

# --- Fase 1: Input Pengguna dan Pembuatan Pengguna ---
create_user_and_system() {
    info "Meminta informasi untuk pengguna dan sistem baru..."
    read -p "Masukkan username untuk pengguna baru: " username
    if [[ -z "$username" ]]; then
        error "Username tidak boleh kosong."
    fi

    read -sp "Masukkan password untuk pengguna '$username': " password
    echo
    if [[ -z "$password" ]]; then
        error "Password tidak boleh kosong."
    fi

    read -p "Masukkan hostname untuk sistem ini: " hostname
    if [[ -z "$hostname" ]]; then
        error "Hostname tidak boleh kosong."
    fi

    info "Membuat pengguna '$username' dan mengkonfigurasi hak sudo..."
    # Membuat pengguna dengan direktori home, dan menambahkannya ke grup wheel
    useradd -m -g users -G wheel -s /bin/bash "$username" || error "Gagal membuat pengguna '$username'."
    # Mengatur password untuk pengguna baru
    echo "$username:$password" | chpasswd || error "Gagal mengatur password."
    info "Pengguna '$username' berhasil dibuat."

    # Mengaktifkan hak sudo untuk grup wheel
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    info "Hak sudo untuk grup 'wheel' telah diaktifkan."

    # Atur hostname
    hostnamectl set-hostname "$hostname"
    info "Hostname diatur ke '$hostname'."
}

# --- Fase 2: Instalasi Paket Inti Sistem ---
install_system_packages() {
    info "Memulai instalasi paket sistem..."
    
    local pacman_packages=(
        # Prasyarat untuk yay & development
        git base-devel
        # Inti Hyprland & Wayland
        hyprland wayland xdg-desktop-portal-hyprland wireplumber pipewire-pulse polkit-kde-agent
        # Tampilan & Tema
        sddm qt5-wayland qt6-wayland qt5ct qt6ct adw-gtk-theme papirus-icon-theme
        # Terminal & Shell
        alacritty fish starship
        # Toolset UI
        waybar wofi mako grim slurp swappy swaybg swaylock
        # Utilitas
        thunar gvfs wl-clipboard cliphist jq curl trash-cli btop bluez bluez-utils network-manager-applet
        # Dependensi SDDM
        qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg
    )

    info "Menginstal paket dari repositori resmi..."
    pacman -Syu --needed --noconfirm "${pacman_packages[@]}" || error "Gagal menginstal paket dari repositori resmi."
    
    success "Paket sistem berhasil diinstal."
}

# --- Fase 3: Instalasi AUR & Konfigurasi Pengguna ---
setup_user_environment() {
    info "Mengkonfigurasi lingkungan untuk pengguna '$username'..."

    # Menjalankan serangkaian perintah sebagai pengguna yang baru dibuat
    # Ini memastikan yay dan semua file config dimiliki oleh pengguna, bukan root.
    su -l "$username" -c "bash -s" <<'EOF'
# --- Fungsi Logging Internal (untuk dijalankan di dalam su) ---
C
