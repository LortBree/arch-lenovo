# Skrip Instalasi Hyprland Mandiri (Catppuccin Themed)

*<p align="center">Tampilan Desktop Hyprland dengan Tema Catppuccin Mocha</p>*

## Deskripsi
Skrip ini bertujuan untuk mengotomatiskan penyiapan lingkungan desktop Hyprland yang lengkap, stabil, dan mandiri di atas instalasi Arch Linux yang baru. Semua file konfigurasi dibuat secara lokal untuk memastikan keandalan dan konsistensi. Estetika terinspirasi dari desain modern dengan palet warna Catppuccin yang nyaman di mata.

Skrip ini dirancang untuk dijalankan sebagai **root** pada instalasi Arch yang baru (di dalam `chroot`).

---

## Fitur & Komponen Utama

| Kategori | Komponen |
| :--- | :--- |
| **Window Manager** | Hyprland (Wayland Compositor) |
| **Panel Status** | Waybar |
| **App Launcher** | Wofi |
| **Terminal** | Alacritty |
| **Notifikasi** | Mako |
| **File Manager** | Thunar |
| **Tema** | Catppuccin Mocha, Papirus Icons, Adwaita GTK |
| **Login Manager** | SDDM dengan tema minimalis |
| **Screenshot Tool**| Grim + Slurp + Swappy |
| **AUR Helper** | Yay |

---

## Prasyarat
Sebelum memulai, pastikan Anda memiliki:
- Instalasi Arch Linux yang baru dan bersih.
- Koneksi internet yang aktif.
- Sistem sudah di-boot dalam mode **UEFI**. Panduan ini spesifik untuk UEFI.
- Media Instalasi (Live USB) Arch Linux siap sedia.

---

## Langkah-Langkah Instalasi

Proses instalasi dibagi menjadi dua tahap: **Instalasi Sistem Dasar (Manual)** dan **Instalasi Desktop (Otomatis dengan Skrip)**.

### Tahap 1: Persiapan Sistem Dasar (Manual)

Langkah-langkah ini dilakukan dari dalam Live USB Arch.

1.  **Koneksi Internet**
    Pastikan Anda terhubung ke internet (`ping archlinux.org`).

2.  **Partisi Disk**
    Gunakan `cfdisk` atau `fdisk` untuk membuat partisi. Skema yang direkomendasikan:
    - **Partisi 1**: `512M` - Tipe: `EFI System`
    - **Partisi 2**: (Ukuran RAM Anda, misal `8G`) - Tipe: `Linux swap`
    - **Partisi 3**: (Sisa ruang, misal `100G` atau lebih) - Tipe: `Linux filesystem`

3.  **Format dan Mount Partisi**
    ```bash
    # Ganti sdXn sesuai dengan nama partisi Anda
    mkfs.fat -F 32 /dev/sda1
    mkswap /dev/sda2
    mkfs.ext4 /dev/sda3

    mount /dev/sda3 /mnt
    swapon /dev/sda2
    mount --mkdir /dev/sda1 /mnt/boot
    ```

4.  **Instalasi Paket Dasar (`pacstrap`)**
    ```bash
    pacstrap -K /mnt base linux linux-firmware networkmanager nano sudo git
    ```

5.  **Generate Fstab**
    ```bash
    genfstab -U /mnt >> /mnt/etc/fstab
    ```

6.  **Chroot ke Sistem Baru**
    ```bash
    arch-chroot /mnt
    ```
    *Anda sekarang berada di dalam sistem baru Anda di hard disk.*

### Tahap 2: Instalasi Desktop (Otomatis dengan Skrip)

Langkah-langkah ini dilakukan **setelah `chroot`**.

1.  **Unduh Skrip Instalasi**
    ```bash
    # Ganti dengan URL skrip Anda
    curl -L -o /root/install.sh "URL_KE_FILE_SCRIPT_ANDA"
    ```

2.  **Beri Izin Eksekusi**
    ```bash
    chmod +x /root/install.sh
    ```

3.  **Jalankan Skrip**
    ```bash
    /root/install.sh
    ```
    Skrip akan meminta input untuk username, password, dan hostname, lalu melanjutkan instalasi secara otomatis.

### ❗ PENTING: Instalasi Bootloader (GRUB)

Langkah ini **KRUSIAL** dan dilakukan **setelah skrip selesai** namun **sebelum Anda reboot**. Tanpa ini, sistem tidak akan bisa booting.

1.  **Install Paket GRUB**
    ```bash
    pacman -S grub efibootmgr
    ```

2.  **Pasang GRUB ke Disk**
    ```bash
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
    ```

3.  **Generate Konfigurasi GRUB**
    ```bash
    grub-mkconfig -o /boot/grub/grub.cfg
    ```

### Langkah Terakhir

Setelah bootloader terpasang, Anda siap untuk reboot.
```bash
exit        # Keluar dari chroot
umount -R /mnt
reboot      # Cabut Live USB Anda!
