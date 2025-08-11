# Arch Install Celestia

Skrip otomatis untuk menginstal **Arch Linux** dengan:
- **Hyprland** sebagai window manager
- **SilentSDDM (Rei)** sebagai display manager
- **Caelestia Shell** dari GitHub

Didesain agar fleksibel: hostname, username, dan password diinput saat instalasi.

---

## 📋 Skema Partisi

Skrip ini mengasumsikan partisi berikut:

| Partisi  | Format | Mount Point |
|----------|--------|-------------|
| /dev/sda1 | FAT32  | /boot       |
| /dev/sda2 | swap   | swap        |
| /dev/sda3 | ext4   | /           |
| /dev/sda4 | ext4   | /home       |

⚠️ **Semua partisi akan diformat ulang! Pastikan backup data Anda.**

---

## 🚀 Cara Pakai

1. Boot ke **Arch Linux Live ISO**.
2. Pastikan koneksi internet aktif:
   ```bash
   ping archlinux.org
3. Jalankan perintah berikut:
curl -O https://raw.githubusercontent.com/LortBree/arch-autoinstall-caelestia/main/arch-caelestia-install.sh
chmod +x arch-caelestia-install.sh
./arch-caelestia-install.sh
