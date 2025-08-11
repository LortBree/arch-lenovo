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

    # Izinkan pacman tanpa password untuk grup wheel selama instalasi
    info "Memberikan izin pacman tanpa password sementara..."
    echo '%wheel ALL=(ALL) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/10-installer

    # Atur hostname
    hostnamectl set-hostname "$hostname"
    info "Hostname diatur ke '$hostname'."
}

# --- Fase 2: Instalasi Paket Inti Sistem ---
install_system_packages() {
    info "Memulai instalasi paket sistem..."
    
    local pacman_packages=(
        # Prasyarat untuk yay & development
        git base-devel go
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
C_RESET='\033[0m'; C_GREEN='\033[0;32m'; C_BLUE='\033[0;34m'; C_RED='\033[0;31m'
info_user() { echo -e "${C_BLUE}[INFO-USER]${C_RESET} $1"; }
success_user() { echo -e "${C_GREEN}[SUCCESS-USER]${C_RESET} $1"; }
error_user() { echo -e "${C_RED}[ERROR-USER]${C_RESET} $1"; exit 1; }

# --- Instalasi Yay ---
info_user "Menginstal pembantu AUR (yay)..."
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm) || error_user "Gagal menginstal yay."
    rm -rf /tmp/yay
else
    info_user "yay sudah terinstal."
fi

# --- Instalasi Paket AUR ---
local aur_packages=(
    sddm-silent-theme-git
    ttf-jetbrains-mono-nerd
)
info_user "Menginstal paket dari AUR..."
yay -S --needed --noconfirm "${aur_packages[@]}" || error_user "Gagal menginstal paket dari AUR."

# --- Generasi Konfigurasi Lokal ---
info_user "Membuat direktori dan file konfigurasi..."
local config_dir="$HOME/.config"

mkdir -p "$config_dir"/{hypr,waybar,wofi,mako,alacritty}

# Konfigurasi Hyprland
info_user "Membuat hyprland.conf..."
cat << 'EOC' > "$config_dir/hypr/hyprland.conf"
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
$mainMod = SUPER
bind = $mainMod, T, exec, alacritty
bind = $mainMod, Q, killactive, 
bind = $mainMod, M, exit, 
bind = $mainMod, E, exec, thunar
bind = $mainMod, D, exec, wofi --show drun
bind = $mainMod, P, pseudo, # dwindle
bind = $mainMod, J, togglesplit, # dwindle
# Move focus
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d
# Switch workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
# Move active window to a workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
# Screenshot
bind = , Print, exec, grim -g "$(slurp)" - | swappy -f -
EOC

# Konfigurasi Waybar
info_user "Membuat konfigurasi Waybar..."
cat << 'EOC' > "$config_dir/waybar/config.jsonc"
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
EOC
cat << 'EOC' > "$config_dir/waybar/style.css"
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
EOC

# Konfigurasi Alacritty
info_user "Membuat alacritty.yml..."
cat << 'EOC' > "$config_dir/alacritty/alacritty.yml"
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
EOC

# Konfigurasi Wofi
info_user "Membuat style.css untuk Wofi..."
cat << 'EOC' > "$config_dir/wofi/style.css"
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
EOC

# Konfigurasi Mako
info_user "Membuat konfigurasi Mako..."
cat << 'EOC' > "$config_dir/mako/config"
font=JetBrainsMono Nerd Font 10
background-color=#1e1e2e
text-color=#cdd6f4
border-color=#89b4fa
border-size=2
border-radius=10
default-timeout=5000
EOC

# Membuat direktori Pictures dan mengunduh wallpaper
mkdir -p "$HOME/Pictures"
info_user "Mengunduh wallpaper default..."
curl -sL -o "$HOME/Pictures/wall.png" "https://w.wallhaven.cc/full/j3/wallhaven-j3m8y5.png"

success_user "Konfigurasi lingkungan pengguna selesai."
EOF
# Akhir dari blok 'su'

    if [[ $? -ne 0 ]]; then
        error "Gagal saat menjalankan konfigurasi sebagai pengguna '$username'. Periksa log di atas."
    fi
    success "Lingkungan pengguna berhasil dikonfigurasi."
}

# --- Fase 4: Pengaturan Layanan Sistem ---
setup_system_services() {
    info "Mengkonfigurasi dan mengaktifkan layanan sistem..."

    # Konfigurasi SDDM
    info "Mengkonfigurasi SDDM dengan tema Silent..."
    local sddm_conf_file="/etc/sddm.conf.d/theme.conf"
    mkdir -p "$(dirname "$sddm_conf_file")"
    tee "$sddm_conf_file" > /dev/null <<EOF
[Theme]
Current=silent

[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard
EOF

    # Aktifkan layanan
    info "Mengaktifkan layanan SDDM, NetworkManager, dan Bluetooth..."
    systemctl enable sddm.service
    systemctl enable NetworkManager.service
    systemctl enable bluetooth.service

    success "Layanan sistem berhasil dikonfigurasi."
}

# --- Fungsi Utama ---
main() {
    pre_flight_checks
    create_user_and_system
    install_system_packages
    setup_user_environment
    setup_system_services

    # Bersihkan aturan sudo sementara
    info "Memberikan izin sudo sementara..."
    rm /etc/sudoers.d/10-intstaller
    
    success "=================================================================="
    success "Instalasi Selesai! Silakan REBOOT sistem Anda sekarang."
    info "Setelah reboot, login sebagai pengguna '$username' di layar SDDM."
    success "=================================================================="
}

# --- Jalankan Skrip ---
main
