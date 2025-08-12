# Panduan Instalasi Arch Linux + Hyprland dengan Dotfiles Caelestia

## Deskripsi
Dokumentasi ini merinci proses instalasi untuk membangun lingkungan desktop Hyprland di Arch Linux. Proses ini menggunakan pendekatan dua tahap:

1.  **Instalasi Fondasi**: Menggunakan skrip eksternal untuk mengotomatiskan instalasi sistem dasar, termasuk Hyprland, user baru, dan `yay`.
2.  **Implementasi Konfigurasi**: Mengganti konfigurasi dasar dengan dotfiles dari Caelestia untuk mendapatkan fungsionalitas dan estetika yang spesifik.

## Prasyarat
- Sistem operasi Arch Linux akan diinstal dari awal.
- Koneksi internet aktif.
- Sistem menggunakan mode boot **UEFI**.
- Media instalasi (Live USB) Arch Linux tersedia.

---

## Prosedur Instalasi

### Tahap 1: Persiapan Sistem Dasar (Manual)

Tahapan ini dilakukan dari Live USB Arch untuk membangun sistem operasi dasar.

1.  **Verifikasi Koneksi Internet**
    Gunakan `ping archlinux.org` untuk memastikan konektivitas.

2.  **Partisi Disk**
    Gunakan `cfdisk`. Skema partisi yang direkomendasikan:
    - **Partisi 1**: `512M` - Tipe: `EFI System`
    - **Partisi 2**: (Ukuran RAM, misal `8G`) - Tipe: `Linux swap`
    - **Partisi 3**: (Sisa ruang) - Tipe: `Linux filesystem`

3.  **Format dan Mount Partisi**
    ```bash
    # Ganti sda dengan nama disk yang sesuai (misal: nvme0n1)
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

5.  **Generate Fstab & Chroot**
    ```bash
    genfstab -U /mnt >> /mnt/etc/fstab
    arch-chroot /mnt
    ```
    *Proses chroot selesai. Anda sekarang beroperasi di dalam sistem yang baru diinstal.*

### Tahap 2: Instalasi Fondasi Desktop (Otomatis)

Setelah proses chroot, jalankan skrip instalasi untuk otomasi pembuatan user dan setup Hyprland dasar.

1.  **Unduh Skrip Instalasi**
    ```bash
    # Opsi -L diperlukan untuk mengikuti redirect dari GitHub
    curl -L -o /root/install.sh "[https://raw.githubusercontent.com/LortBree/arch-lenovo/main/install.sh](https://raw.githubusercontent.com/LortBree/arch-lenovo/main/install.sh)"
    ```

2.  **Tetapkan Izin Eksekusi**
    ```bash
    chmod +x /root/install.sh
    ```

3.  **Jalankan Skrip**
    ```bash
    /root/install.sh
    ```
    Skrip akan meminta input untuk username, password, dan hostname. Masukkan data yang diperlukan.

4.  **Instal Bootloader dan Login Manager**
    Setelah eksekusi skrip selesai, instalasi bootloader dan login manager diperlukan sebelum reboot.
    ```bash
    # Instal GRUB & SDDM (opsi --needed mencegah instalasi ulang)
    pacman -S --needed grub efibootmgr sddm

    # Pasang GRUB ke disk
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
    grub-mkconfig -o /boot/grub/grub.cfg

    # Aktifkan layanan Login Manager
    systemctl enable sddm
    ```
5.  **Reboot Sistem**
    ```bash
    exit        # Keluar dari chroot
    umount -R /mnt
    reboot      # Lepaskan Live USB
    ```
    Setelah reboot, sistem akan masuk ke sesi Hyprland dasar.

---

### Tahap 3: Transformasi ke Dotfiles Caelestia

Proses ini dilakukan dari dalam sesi Hyprland yang sudah berjalan. Buka terminal (`Super + T`) untuk melanjutkan.

1.  **Instal Dependensi Caelestia**
    Gunakan `yay` untuk menginstal meta-package. Perintah ini akan menarik semua paket dan font yang dibutuhkan secara otomatis.
    ```bash
    yay -S caelestia-meta
    ```

2.  **Backup dan Pindahkan Konfigurasi Awal**
    Konfigurasi yang ada harus dipindahkan untuk mencegah konflik dengan dotfiles baru.
    ```bash
    # Buat direktori backup
    mkdir -p ~/config-backup-awal

    # Pindahkan konfigurasi dari skrip awal ke direktori backup
    mv ~/.config/hypr ~/.config/waybar ~/.config/wofi ~/.config/alacritty ~/.config/mako ~/config-backup-awal/
    ```

3.  **Clone dan Jalankan Skrip Caelestia**
    Clone repositori ke direktori yang direkomendasikan dan jalankan skrip instalasinya.
    ```bash
    # Clone repositori
    git clone [https://github.com/caelestia-dots/caelestia.git](https://github.com/caelestia-dots/caelestia.git) ~/.local/share/caelestia

    # Pindah ke direktori repositori dan jalankan skrip install.fish
    cd ~/.local/share/caelestia
    chmod +x install.fish
    ./install.fish
    ```

4.  **Finalisasi**
    Setelah skrip selesai, logout dan login kembali dari SDDM untuk menerapkan semua perubahan.

---
## Informasi Tambahan
- File konfigurasi utama sekarang berada di `~/.local/share/caelestia`. Modifikasi file di direktori ini untuk melakukan kustomisasi.
- Untuk memperbarui dotfiles, masuk ke direktori `~/.local/share/caelestia` dan jalankan `git pull`.

