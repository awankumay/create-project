# __PROJECT_NAME__ — Laravel + Flutter offline draft starter

Aplikasi nyata dibuat dari skeleton Laravel resmi dan `flutter create`. Contoh ini menyimpan draft lokal dengan antrean pengiriman persisten. Draft bersifat append-only; belum ada edit/hapus, stok, pembayaran atau posting akuntansi offline.

## Jalankan backend

```bash
cd apps/backend
php artisan starter:user admin@example.com --name="Administrator" --admin
php artisan serve --host=0.0.0.0 --port=8000
```

Buat password Anda sendiri pada prompt. Panel: http://127.0.0.1:8000/admin. Gunakan akun yang sama di client agar draft milik Anda terlihat di panel. User non-admin dapat memakai API tetapi tidak dapat masuk panel.

## Jalankan client

```bash
cd apps/client
flutter run -d windows
# atau Android emulator/perangkat
flutter run
```

Client default Android emulator: http://10.0.2.2:8000. Windows: http://127.0.0.1:8000. Android fisik: IP LAN komputer server, misalnya http://192.168.1.10:8000. Izinkan port pada firewall jaringan development yang sesuai. Release wajib menggunakan HTTPS; HTTP diizinkan oleh manifest Android debug saja.

## Uji offline

1. Login online sekali, lalu simpan satu draft dan sinkronkan.
2. Hentikan Laravel/server atau putus akses jaringan ke server.
3. Simpan draft lain. Statusnya menunggu sinkronisasi.
4. Tutup aplikasi seluruhnya dan buka kembali. Draft dan antrean tetap ada.
5. Jalankan server kembali dan tekan sinkronkan. Status berubah tersinkronisasi.
6. Tekan sinkronkan lagi. Server tetap hanya mempunyai satu record per draft.
7. Logout, lalu masuk sebagai akun lain: draft akun sebelumnya tidak terlihat atau terkirim.

Aplikasi mencoba sync saat terbuka setiap 20 detik, saat kembali ke foreground, setelah menyimpan, dan melalui tombol. Backoff disimpan di database. Tidak menjamin background sync ketika aplikasi ditutup. Jika sesi 7 hari kedaluwarsa, data lokal dapat dibaca tetapi pembuatan draft baru diblok sampai login online kembali. Server selalu memvalidasi token; jam perangkat bukan otoritas keamanan.

## Bila memakai --skip-install

```bash
cd apps/backend
composer install
php artisan key:generate
php artisan filament:assets
php artisan migrate
php artisan test --compact --filter=OfflineDraftSyncTest
```

Gunakan database SQLite demo yang dibuat installer. Sebelum beralih MySQL, isi konfigurasi database dan tinjau migration. Untuk client:

```bash
cd apps/client
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format lib test
flutter analyze
flutter test
```

Jangan mengganti APP_KEY aplikasi yang sudah digunakan. File `.env`, SQLite, token, dan data user tidak boleh masuk Git. Commit lockfile hasil Composer dan Flutter setelah instalasi berhasil.

Baca docs/OFFLINE.md, docs/SECURITY.md dan packages/api-contracts/openapi.yaml. Build Windows memerlukan Windows + Visual Studio C++ tools; Android memerlukan Android SDK. Starter tidak membuat file .exe/APK secara otomatis.
