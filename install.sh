#!/bin/bash

# ==============================================================================
# Skrip Instalasi Otomatis Arch Linux + Hyprland (Estetika Caelestia)
# Versi: 1.1 (Debugged)
#
# Deskripsi:
# Skrip ini mengotomatiskan penyiapan lingkungan desktop Hyprland yang lengkap
# di Arch Linux, dengan tema Caelestia. Skrip ini secara khusus mengintegrasikan
# Waybar sebagai bilah status, menyimpang dari Caelestia Quickshell default
# untuk memenuhi persyaratan kustomisasi.
#
# Peringatan:
# - Jalankan skrip ini pada instalasi Arch Linux yang bersih.
# - Skrip ini akan menginstal paket dan mengkonfigurasi file sistem.
# - Diperlukan koneksi internet.
# ==============================================================================

# --- Konfigurasi Warna dan Fungsi Logging ---
C_RESET='\033]; then
        error "Jangan menjalankan skrip ini sebagai root. Jalankan sebagai pengguna biasa dengan hak sudo."
    fi

    # Periksa konektivitas internet
    if! ping -c 1 -W 1 archlinux.org &> /dev/null; then
        error "Tidak ada koneksi internet. Harap sambungkan ke internet dan coba lagi."
    fi
    
    success "Pemeriksaan pra-instalasi selesai."
}

get_user_input() {
    info "Meminta input pengguna..."
    read -p "Masukkan hostname untuk sistem ini: " hostname
    if [[ -z "$hostname" ]]; then
        error "Hostname tidak boleh kosong."
    fi

    # Pengguna saat ini akan menjadi pengguna utama
    local username=$(whoami)
    info "Instalasi akan dilakukan untuk pengguna: $username"
    
    # Meminta password hanya untuk konfirmasi sudo di awal
    info "Meminta hak akses sudo untuk melanjutkan instalasi..."
    sudo -v
    if [[ $? -ne 0 ]]; then
        error "Gagal mendapatkan hak sudo. Pastikan pengguna '$username' ada di grup wheel."
    fi

    success "Input pengguna telah diterima."
}

# --- Fase 1: Bootstrap Sistem & Instalasi Yay ---
install_yay() {
    info "Memeriksa dan menginstal pembantu AUR (yay)..."
    if! command -v yay &> /dev/null; then
        info "yay tidak ditemukan. Menginstal yay..."
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        rm -rf /tmp/yay
    else
        info "yay sudah terinstal."
    fi
    success "yay berhasil diinstal dan siap digunakan."
}

# --- Fase 2: Instalasi Dependensi ---
install_packages() {
    info "Memulai instalasi paket..."
    
    # Daftar paket dari repositori resmi
    local pacman_packages=(
        # Inti Hyprland & Wayland
        hyprland wayland xdg-desktop-portal-hyprland wireplumber pipewire-pulse
        # Terminal & Shell
        foot fish starship
        # Utilitas Sistem & CLI
        wl-clipboard cliphist grim slurp swappy jq polkit-kde-agent
        imagemagick curl trash-cli btop bluez bluez-utils
        # Tema & Tampilan
        sddm adw-gtk-theme papirus-icon-theme qt5-wayland qt6-wayland qt5ct qt6ct
        # Dependensi SDDM & CLI
        qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg libnotify dart-sass
        python-build python-installer python-hatch python-hatch-vcs
        # UI Kustom
        waybar
    )

    # Daftar paket dari AUR
    local aur_packages=(
        caelestia-cli-git
        sddm-silent-theme-git
        eww-wayland # Opsional, jika ingin menggunakan Eww
        ttf-jetbrains-mono-nerd
    )

    info "Menginstal paket dari repositori resmi..."
    sudo pacman -S --needed --noconfirm "${pacman_packages[@]}"
    if [[ $? -ne 0 ]]; then
        error "Gagal menginstal paket dari repositori resmi."
    fi

    info "Menginstal paket dari AUR..."
    yay -S --needed --noconfirm "${aur_packages[@]}"
    if [[ $? -ne 0 ]]; then
        error "Gagal menginstal paket dari AUR."
    fi

    success "Semua paket dependensi berhasil diinstal."
}

# --- Fase 3: Konfigurasi & Tema ---
configure_system() {
    info "Memulai konfigurasi sistem dan dotfiles..."

    # Atur hostname
    sudo hostnamectl set-hostname "$hostname"
    info "Hostname diatur ke '$hostname'."

    # Kloning repositori dotfiles Caelestia
    local caelestia_dir="$HOME/.local/share/caelestia"
    if [ -d "$caelestia_dir" ]; then
        warn "Direktori Caelestia sudah ada di '$caelestia_dir'. Melewatkan kloning."
    else
        info "Mengkloning dotfiles Caelestia ke '$caelestia_dir'..."
        git clone https://github.com/caelestia-dots/caelestia.git "$caelestia_dir"
    fi
    
    # Jalankan skrip instalasi fish dari Caelestia untuk symlink
    # Ini akan menautkan config untuk hypr, foot, fish, btop, dll.
    info "Menjalankan skrip instalasi Caelestia untuk membuat symlink..."
    if [ -f "$caelestia_dir/install.fish" ]; then
        fish -c "source $caelestia_dir/install.fish"
    else
        error "Skrip install.fish tidak ditemukan di repositori Caelestia."
    fi

    # Konfigurasi Waybar Kustom
    info "Menyebarkan konfigurasi Waybar kustom..."
    local waybar_config_dir="$HOME/.config/waybar"
    mkdir -p "$waybar_config_dir"

    # Buat file config Waybar
    cat << EOF > "$waybar_config_dir/config.jsonc"
{
    "layer": "top",
    "position": "top",
    "height": 48,
    "spacing": 4,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "cpu", "memory", "tray"],
    
    "hyprland/workspaces": {
        "format": "{icon}",
        "on-click": "activate",
        "format-icons": {
            "1": "",
            "2": "",
            "3": "",
            "4": "",
            "5": "",
            "default": ""
        }
    },
    "hyprland/window": {
        "format": "{}",
        "max-length": 35
    },
    "clock": {
        "format": " {:%H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\\n<tt><small>{calendar}</small></tt>"
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": " Muted",
        "format-icons": {
            "default": ["", ""]
        },
        "on-click": "pavucontrol"
    },
    "network": {
        "format-wifi": "  {essid}",
        "format-ethernet": "󰈀 {ifname}",
        "format-disconnected": "󰖪 Disconnected",
        "tooltip-format": "{ifname} via {gwaddr} ",
        "on-click": "nm-connection-editor"
    },
    "cpu": {
        "format": " {usage}%",
        "tooltip": true
    },
    "memory": {
        "format": " {}%"
    },
    "tray": {
        "icon-size": 18,
        "spacing": 10
    }
}
EOF

    # Buat file style CSS Waybar yang terinspirasi Caelestia
    cat << EOF > "$waybar_config_dir/style.css"
* {
    border: none;
    border-radius: 12px;
    font-family: 'JetBrainsMono Nerd Font';
    font-size: 14px;
    min-height: 0;
}

window#waybar {
    background: transparent;
}

#workspaces,
#window,
#clock,
#pulseaudio,
#network,
#cpu,
#memory,
#tray {
    background: #1e1e2e;
    color: #cdd6f4;
    padding: 5px 15px;
    margin: 6px 3px;
    border: 1px solid #313244;
}

#workspaces button {
    color: #45475a;
    padding: 0 5px;
}

#workspaces button.active {
    color: #89b4fa;
}

#workspaces button:hover {
    background: #313244;
    color: #cdd6f4;
}
EOF

    # Modifikasi hyprland.conf untuk meluncurkan Waybar
    info "Memodifikasi hyprland.conf untuk meluncurkan Waybar..."
    local hypr_config="$HOME/.config/hypr/hyprland.conf"
    # Hapus baris yang menjalankan shell Caelestia jika ada
    sed -i '/exec-once = caelestia-shell/d' "$hypr_config"
    # Tambahkan baris untuk menjalankan Waybar
    echo -e "\n# Jalankan Waybar\nexec-once = waybar" >> "$hypr_config"

    success "Konfigurasi sistem dan dotfiles selesai."
}

# --- Fase 4: Layanan Sistem ---
setup_services() {
    info "Mengkonfigurasi dan mengaktifkan layanan sistem..."

    # Konfigurasi SDDM dengan tema Silent
    info "Mengkonfigurasi SDDM..."
    local sddm_conf_file="/etc/sddm.conf.d/theme.conf"
    sudo mkdir -p "$(dirname "$sddm_conf_file")"
    sudo tee "$sddm_conf_file" > /dev/null <<EOF

Current=silent

[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard
EOF
    
    # Aktifkan layanan SDDM dan lainnya
    info "Mengaktifkan layanan..."
    sudo systemctl enable sddm.service
    sudo systemctl enable bluetooth.service

    success "Layanan sistem berhasil dikonfigurasi dan diaktifkan."
}

# --- Fungsi Utama ---
main() {
    pre_flight_checks
    get_user_input
    
    install_yay
    install_packages
    configure_system
    setup_services

    success "=================================================================="
    success "Instalasi Selesai! Silakan REBOOT sistem Anda sekarang."
    info "Setelah reboot, Anda akan disambut oleh layar login SDDM. Masuk dengan kredensial Anda."
    success "=================================================================="
}

# --- Jalankan Skrip ---
main
