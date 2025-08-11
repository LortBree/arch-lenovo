#!/bin/bash

# ==============================================================================
# Skrip Instalasi Hyprland Mandiri - Versi 2.0 (Stabil)
#
# Deskripsi:
# Skrip ini mengotomatiskan penyiapan lingkungan desktop Hyprland yang lengkap,
# stabil, dan mandiri di Arch Linux. Semua file konfigurasi dibuat secara lokal
# untuk memastikan keandalan dan menghindari masalah dengan dotfiles eksternal.
# Estetika terinspirasi dari desain modern menggunakan palet Catppuccin.
#
# Peringatan:
# - Jalankan pada instalasi Arch Linux yang bersih sebagai pengguna non-root.
# - Diperlukan koneksi internet dan hak akses sudo.
# ==============================================================================

# --- Konfigurasi Warna dan Fungsi Logging ---
C_RESET='\033]; then
        error "Jangan menjalankan skrip ini sebagai root. Jalankan sebagai pengguna biasa dengan hak sudo."
    fi

    if! ping -c 1 -W 1 archlinux.org &> /dev/null; then
        error "Tidak ada koneksi internet. Harap sambungkan dan coba lagi."
    fi
    
    success "Pemeriksaan pra-instalasi selesai."
}

get_user_input() {
    info "Meminta input pengguna..."
    read -p "Masukkan hostname untuk sistem ini: " hostname
    if [[ -z "$hostname" ]]; then
        error "Hostname tidak boleh kosong."
    fi

    info "Meminta hak akses sudo untuk melanjutkan instalasi..."
    sudo -v
    if [[ $? -ne 0 ]]; then
        local username=$(whoami)
        error "Gagal mendapatkan hak sudo. Pastikan pengguna '$username' ada di grup 'wheel'."
    fi

    success "Input pengguna telah diterima."
}

# --- Fase 1: Instalasi Yay (AUR Helper) ---
install_yay() {
    info "Memeriksa dan menginstal pembantu AUR (yay)..."
    if! command -v yay &> /dev/null; then
        info "yay tidak ditemukan. Menginstal..."
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        rm -rf /tmp/yay
    else
        info "yay sudah terinstal."
    fi
    success "yay siap digunakan."
}

# --- Fase 2: Instalasi Paket Inti ---
install_packages() {
    info "Memulai instalasi paket..."
    
    local pacman_packages=(
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

    local aur_packages=(
        sddm-silent-theme-git
        ttf-jetbrains-mono-nerd
    )

    info "Menginstal paket dari repositori resmi..."
    sudo pacman -S --needed --noconfirm "${pacman_packages[@]}" |

| error "Gagal menginstal paket dari repositori resmi."

    info "Menginstal paket dari AUR..."
    yay -S --needed --noconfirm "${aur_packages[@]}" |

| error "Gagal menginstal paket dari AUR."

    success "Semua paket dependensi berhasil diinstal."
}

# --- Fase 3: Generasi Konfigurasi Lokal ---
generate_configs() {
    info "Membuat direktori dan file konfigurasi..."
    local config_dir="$HOME/.config"

    # Membuat struktur direktori
    mkdir -p "$config_dir"/{hypr,waybar,wofi,mako,alacritty}

    # Konfigurasi Hyprland
    info "Membuat hyprland.conf..."
    cat << EOF > "$config_dir/hypr/hyprland.conf"
# --- Monitor ---
monitor=,preferred,auto,1

# --- Autostart ---
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = waybar
exec-once = swaybg -i $HOME/Pictures/wall.png # Ganti dengan path wallpaper Anda
exec-once = mako

# --- Source Files ---
# source = ~/.config/hypr/myColors.conf

# --- Environment Variables ---
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORMTHEME,qt5ct

# --- Input ---
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = no
    }
    sensitivity = 0
}

# --- General ---
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(cba6f7ff) rgba(89b4faff) 45deg
    col.inactive_border = rgba(45475aff)
    layout = dwindle
}

# --- Decoration ---
decoration {
    rounding = 10
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    drop_shadow = yes
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(11111bff)
}

# --- Animations ---
animations {
    enabled = yes
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# --- Dwindle Layout ---
dwindle {
    pseudotile = yes
    preserve_split = yes
}

# --- Gestures ---
gestures {
    workspace_swipe = off
}

# --- Keybinds ---
\$mainMod = SUPER

bind = \$mainMod, T, exec, alacritty
bind = \$mainMod, Q, killactive, 
bind = \$mainMod, M, exit, 
bind = \$mainMod, E, exec, thunar
bind = \$mainMod, D, exec, wofi --show drun
bind = \$mainMod, P, pseudo, # dwindle
bind = \$mainMod, J, togglesplit, # dwindle

# Move focus
bind = \$mainMod, left, movefocus, l
bind = \$mainMod, right, movefocus, r
bind = \$mainMod, up, movefocus, u
bind = \$mainMod, down, movefocus, d

# Switch workspaces
bind = \$mainMod, 1, workspace, 1
bind = \$mainMod, 2, workspace, 2
bind = \$mainMod, 3, workspace, 3

# Move active window to a workspace
bind = \$mainMod SHIFT, 1, movetoworkspace, 1
bind = \$mainMod SHIFT, 2, movetoworkspace, 2
bind = \$mainMod SHIFT, 3, movetoworkspace, 3

# Screenshot
bind = , Print, exec, grim -g "\$(slurp)" - | swappy -f -
EOF

    # Konfigurasi Waybar
    info "Membuat konfigurasi Waybar..."
    cat << EOF > "$config_dir/waybar/config.jsonc"
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
        "format-icons": { "default": "", "active": "" }
    },
    "clock": { "format": " {:%H:%M}" },
    "pulseaudio": { "format": "{icon} {volume}%", "format-icons": { "default": ["", "", ""] } },
    "network": { "format-wifi": "  {essid}", "format-ethernet": "󰈀 Connected" },
    "cpu": { "format": " {usage}%" },
    "memory": { "format": " {}%" },
    "tray": { "icon-size": 18, "spacing": 10 }
}
EOF

    cat << EOF > "$config_dir/waybar/style.css"
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

#workspaces, #window, #clock, #pulseaudio, #network, #cpu, #memory, #tray {
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
EOF

    # Konfigurasi Alacritty
    info "Membuat alacritty.yml..."
    cat << EOF > "$config_dir/alacritty/alacritty.yml"
window:
  opacity: 0.9
font:
  normal:
    family: JetBrainsMono Nerd Font
    style: Regular
  size: 11.0

# Catppuccin Mocha
colors:
  primary:
    background: '0x1e1e2e'
    foreground: '0xcdd6f4'
  normal:
    black:   '0x45475a'
    red:     '0xf38ba8'
    green:   '0xa6e3a1'
    yellow:  '0xf9e2af'
    blue:    '0x89b4fa'
    magenta: '0xf5c2e7'
    cyan:    '0x94e2d5'
    white:   '0xbac2de'
EOF

    # Konfigurasi Wofi
    info "Membuat style.css untuk Wofi..."
    cat << EOF > "$config_dir/wofi/style.css"
window {
    background-color: #1e1e2e;
    border: 2px solid #89b4fa;
    border-radius: 15px;
}

#input {
    background-color: #313244;
    color: #cdd6f4;
    border-radius: 10px;
    border: none;
    padding: 10px;
}

#inner-box {
    margin: 10px;
}

#entry:selected {
    background-color: #89b4fa;
    color: #1e1e2e;
}
EOF

    # Konfigurasi Mako
    info "Membuat konfigurasi Mako..."
    cat << EOF > "$config_dir/mako/config"
font=JetBrainsMono Nerd Font 10
background-color=#1e1e2e
text-color=#cdd6f4
border-color=#89b4fa
border-size=2
border-radius=10
default-timeout=5000
EOF

    # Membuat direktori Pictures jika belum ada dan mengunduh wallpaper default
    mkdir -p "$HOME/Pictures"
    info "Mengunduh wallpaper default..."
    curl -sL -o "$HOME/Pictures/wall.png" "https://w.wallhaven.cc/full/j3/wallhaven-j3m8y5.png" |

| warn "Gagal mengunduh wallpaper. Silakan atur secara manual."

    success "Semua file konfigurasi berhasil dibuat."
}

# --- Fase 4: Pengaturan Layanan Sistem ---
setup_services() {
    info "Mengkonfigurasi dan mengaktifkan layanan sistem..."

    # Atur hostname
    sudo hostnamectl set-hostname "$hostname"
    info "Hostname diatur ke '$hostname'."

    # Konfigurasi SDDM
    info "Mengkonfigurasi SDDM dengan tema Silent..."
    local sddm_conf_file="/etc/sddm.conf.d/theme.conf"
    sudo mkdir -p "$(dirname "$sddm_conf_file")"
    sudo tee "$sddm_conf_file" > /dev/null <<EOF

Current=silent

[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard
EOF

    # Aktifkan layanan
    info "Mengaktifkan layanan SDDM, NetworkManager, dan Bluetooth..."
    sudo systemctl enable sddm.service
    sudo systemctl enable NetworkManager.service
    sudo systemctl enable bluetooth.service

    success "Layanan sistem berhasil dikonfigurasi."
}

# --- Fungsi Utama ---
main() {
    pre_flight_checks
    get_user_input
    
    install_yay
    install_packages
    generate_configs
    setup_services

    success "=================================================================="
    success "Instalasi Selesai! Silakan REBOOT sistem Anda sekarang."
    info "Setelah reboot, Anda akan disambut oleh layar login SDDM."
    success "=================================================================="
}

# --- Jalankan Skrip ---
main
