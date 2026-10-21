# Create Project — Laravel + Flutter Offline Starter

Installer untuk membuat project Laravel 13 + Filament 5, dengan pilihan aplikasi Flutter Android/Windows yang dapat menyimpan draft tanpa koneksi server.

**Ini starter pengembangan, bukan ERP/HRIS siap produksi.** Fondasi yang disertakan: login API Sanctum, panel admin, SQLite/Drift lokal, outbox persisten, retry, idempotency server, pull cursor, dan isolasi data per server+akun. Detail protokol: [OFFLINE.md](templates/project/docs/OFFLINE.md).

## Mulai dari Git Bash / Linux / macOS

```bash
set -o pipefail
curl -fsSL https://raw.githubusercontent.com/awankumay/create-project/main/create-project.sh \
  | bash -s -- mitra-business --preset laravel-offline
```

Script installer dijalankan melalui stdin; tidak perlu mengunduh ZIP secara manual. Launcher mengambil repository template sementara dan membersihkannya sesudah selesai. Folder project hasil tetap tersimpan di direktori aktif.

Persyaratan: **PHP 8.4+, Composer 2, Git**, serta **Flutter stable dengan Dart 3.10+** untuk preset offline. Ekstensi PHP standar Laravel/Filament termasuk intl, mbstring, pdo_sqlite, dom/xml, curl dan fileinfo diperlukan. Installer memeriksa dependency sebelum membuat target. Jalankan `flutter doctor -v` untuk menyiapkan SDK Android atau toolchain Windows.

Bash dan Python kini menjadi launcher untuk **satu implementasi installer PHP** agar logika instalasi tidak berbeda. Keduanya tetap membutuhkan PHP; ini sesuai kebutuhan runtime Laravel. Versi generator folder sebelumnya tersedia di [legacy/](legacy/).

## Pilihan profil

| Profil | Hasil |
|---|---|
| `laravel-offline` (default) | Laravel + Filament + API + Flutter Android/Windows + contoh draft offline |
| `laravel-admin` | Laravel + Filament + API; tanpa aplikasi Flutter |

```bash
bash create-project.sh my-admin --preset laravel-admin
php create-project.php my-app --preset laravel-offline
python create-project.py my-app --preset laravel-offline
```

Perintah lokal di atas dijalankan dari repository yang telah di-clone. Bila hanya file Bash/Python diunduh, launcher mengambil template lengkap melalui Git. PHP entry point memerlukan checkout lengkap. Di Windows, `py -3` dapat menggantikan `python`.

Opsi:

| Opsi | Kegunaan |
|---|---|
| `--parent PATH` | Folder induk, default direktori aktif |
| `--preset PROFILE` | Pilih salah satu profil di atas |
| `--mobile` | Alias untuk `--preset laravel-offline` |
| `--dry-run` | Perlihatkan rencana tanpa membuat project |
| `--skip-install` | Buat source aplikasi tanpa Composer/pub install, codegen dan migration |

`--skip-install` tetap mengambil skeleton Laravel melalui Git dan menjalankan `flutter create --no-pub` untuk profil offline; Flutter SDK tetap diperlukan. Hasil belum dapat dijalankan sampai langkah setup selesai.

Contoh pratinjau:

```bash
curl -fsSL https://raw.githubusercontent.com/awankumay/create-project/main/create-project.sh \
  | bash -s -- mitra-business --dry-run
```

`--modules` dan `--gateway` dari generator lama tidak berlaku pada installer baru. Fondasi ini memakai struktur standar Laravel. Pilih batas modul bisnis setelah alur sync terbukti; jangan membuat package modular kosong yang tampak aktif. Goravel tetap merupakan opsi integrasi perangkat di tahap terpisah dan belum diprovisikan installer.

## Yang dilakukan installer

1. Periksa nama, profil, dependency dan target yang belum ada.
2. Ambil skeleton Laravel 13 resmi pada commit yang dikunci di `installer/install.php`; simpan lisensi aslinya.
3. Tambahkan Filament, Sanctum, draft API, migration, read-only panel dan pengujian.
4. Untuk profil offline, jalankan `flutter create` lalu tambahkan Drift, secure token storage, UI draft dan sync engine.
5. Install dependency, generate APP_KEY baru, publish aset Filament, jalankan migration pada **SQLite demo baru** dan pengujian backend. Jalankan Flutter codegen, analyze dan test.
6. Pindahkan project dari staging ke nama tujuan setelah seluruh langkah berhasil.

Tidak ada akun atau password default. Tidak ada database produksi yang disentuh. Target existing dan symlink ditolak. Jika gagal, staging dipertahankan beserta lokasi untuk pemeriksaan; tidak ada overwrite/cleanup data project otomatis.

Composer dan Flutter menyelesaikan dependency dari constraint template pada waktu install. Skeleton Laravel dipin, tetapi resolusi dependency belum identik antar waktu sebelum lockfile dihasilkan. Commit `composer.lock` dan `pubspec.lock` pada project baru sesudah instalasi berhasil. Flutter runner dibuat oleh SDK lokal; catat versi SDK untuk reproduksi build.

## Struktur hasil

```text
my-app/
  apps/
    backend/                 # aplikasi Laravel + Filament + Sanctum
    client/                  # satu Flutter app: Android dan Windows
  packages/api-contracts/     # OpenAPI v1
  infra/                     # panduan; deployment production belum diprovisikan
  docs/                      # offline protocol, security, platform setup
  AGENTS.md
  starter-source.json
```

Nama `client` dipilih karena aplikasi ini mendukung mobile sekaligus desktop. Tidak perlu memisahkan repo atau menduplikasi logika sync untuk dua target tersebut. UI dan integrasi hardware tetap dapat memerlukan penyesuaian platform.

## Setelah berhasil

```bash
cd my-app/apps/backend
php artisan starter:user admin@example.com --name="Administrator" --admin
php artisan serve --host=0.0.0.0 --port=8000
```

Panel: http://127.0.0.1:8000/admin. Password diminta secara interaktif dan tidak dicatat di script. Kemudian:

```bash
cd my-app/apps/client
flutter run -d windows
# atau flutter run untuk Android
```

Build Windows memerlukan **Windows + Visual Studio dengan Desktop development with C++**, bukan hanya VS Code. Build Android memerlukan SDK/emulator/perangkat Android. Instalasi ini tidak otomatis menghasilkan .exe/APK.

Alamat API: Windows lokal `http://127.0.0.1:8000`, emulator Android `http://10.0.2.2:8000`, perangkat fisik memakai IP LAN server. Android debug mengizinkan HTTP LAN; produksi wajib HTTPS. Lihat README hasil project untuk langkah offline dan setup tertunda.

## Batas offline dan keamanan

- Login pertama online; token berumur 7 hari. Draft disimpan lokal dan dikirim saat aplikasi aktif, setelah menyimpan, saat resume, atau lewat tombol.
- Draft dan outbox disimpan atomik; retry memakai ID yang sama. Pengiriman ulang identik tidak menggandakan record server.
- Tidak ada jaminan sync ketika aplikasi ditutup, saldo stok global offline, verifikasi pembayaran offline, atau posting akuntansi.
- Contoh draft append-only: belum ada edit/hapus, tombstones, atau resolusi konflik perubahan record.
- SQLite draft **belum dienkripsi**. Token disimpan melalui OS secure storage. Terapkan kebijakan perangkat dan data sebelum memuat data sensitif.
- Permission contoh: is_admin untuk panel serta token abilities dan kepemilikan record API. Belum ada RBAC granular atau scope company/location.

## Pengujian

Workflow [Starter verification](.github/workflows/starter.yml) memasang starter lengkap, memeriksa boot/routes, dan menjalankan tes yang dihasilkan.

Backend: replay identik, konflik key, penolakan overwrite, auth/abilities/ownership, cursor, login/logout, dan akses panel.

Flutter: persistensi setelah database dibuka ulang, respons hilang dengan pengiriman ulang payload identik, pemisahan akun/server, penolakan 422, sesi 401 dan transaksi pull/cursor.

Status pengujian lokal/CI dicatat di [docs/VALIDATION.md](docs/VALIDATION.md). Workflow yang tersedia belum otomatis berarti seluruh pemeriksaan sudah lulus. Pengujian Windows/Android native, printer/scanner dan penilaian production tetap terpisah.

## Sumber

- [Laravel 13 installation](https://laravel.com/docs/13.x/installation)
- [Filament 5 installation](https://filamentphp.com/docs/5.x/introduction/installation)
- [Flutter architecture and offline-first](https://docs.flutter.dev/app-architecture/design-patterns/offline-first)
- [Flutter desktop](https://docs.flutter.dev/platform-integration/desktop)
- [Drift native platforms](https://drift.simonbinder.eu/platforms/vm/)

[REVIEW.md](REVIEW.md) adalah review struktural ERP/HRIS sebelumnya, bukan audit fitur starter ini. Kode starter baru berlisensi MIT; dependency dan skeleton mempertahankan lisensi masing-masing.
