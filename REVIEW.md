# Review struktur — 21 Oktober 2026

Sumber yang diperiksa melalui GitHub: tree recursive, composer.json kedua branch, README dan AGENTS HRIS, scripts/setup.sh kedua project, CI dan docker-compose ERP.

- ERP feat/pst: ca68496dd75923aad51f44cd2ff49e9940f1f052
- HRIS develop: f0a4d7e8d0f02a921212914cb4c6b0758b2c1270

## Kesimpulan
Adopsi susunan monorepo HRIS; pertahankan internachi/modular ERP. HRIS menggunakan App namespace standar tanpa internachi/modular pada composer.json; ERP memakai 11 local Composer packages. Monorepo dan modularisasi adalah keputusan berbeda dan bisa dipakai bersama.

Struktur target:

```text
project/
  apps/
    backend/
      artisan
      composer.json
      composer.lock
      app/
      app-modules/
      bootstrap/
      config/
      database/
      resources/
      routes/
      tests/
      patches/
      Dockerfile
    mobile/                 # opsional
    gateway/                # opsional
  packages/api-contracts/
  infra/
    production/
  scripts/
  docs/
```

## Temuan
| Area | ERP feat/pst | HRIS develop | Rekomendasi |
|---|---|---|---|
| Layout | Laravel di root | apps/backend | Pindahkan unit aplikasi Laravel bersama |
| Modul | internachi/modular ^3.0; 11 modules/* | App namespace; tanpa dependency modular | Pertahankan modul ERP |
| Mobile/gateway | Tidak ada apps/mobile atau apps/gateway | Keduanya tersedia | Tambahkan sesuai kebutuhan |
| Kontrak | docs/api | packages/api-contracts | Pisahkan kontrak lintas aplikasi |
| Docker | docker-compose.yml di root | infra dan infra/production | Sesuaikan build context, env_file dan mount |
| CI | Command dan dependency mengasumsikan root | Workflow per aplikasi | Arahkan command dan cache ke apps/backend |
| Setup | Khusus CLAUDE_CODE_REMOTE, mengganti APP_KEY setiap eksekusi | Dispatcher per aplikasi | Buat setup lokal; generate key hanya saat awal |

Modul ERP saat diperiksa: accounting, core, finance, hris, inventory, master-data, printing, purchasing, rental, requester, sales.

README HRIS menyebut mobile masih placeholder, tetapi tree sudah berisi lib, android, ios dan pubspec. Status README perlu disinkronkan; folder bukan bukti kesiapan atau kelulusan pengujian.

composer ERP mendeklarasikan PHP ^8.3, sementara HRIS ^8.4 dan CI ERP menggunakan 8.4. Verifikasi composer.lock dengan composer check-platform-reqs; jangan menyimpulkan kompatibilitas PHP 8.3 hanya dari root requirement.

Docker ERP memakai fallback password serta healthcheck MySQL dengan password root literal. Rapikan konfigurasi rahasia dan healthcheck ketika merestrukturisasi. Jangan gunakan contoh credential untuk produksi.

## Pemindahan project ERP existing
1. Buat branch refactor terpisah. Rekam hasil test dan versi sebelum perubahan.
2. Pindahkan keseluruhan aplikasi ke apps/backend: app-modules harus tetap satu level dengan composer.json sehingga repositories.url=app-modules/* tetap berlaku. Namespace tidak perlu diubah.
3. Pertahankan composer.lock, package-lock.json, patches, stubs, config dan aset. Hindari menyalin vendor/node_modules; install ulang di lokasi baru.
4. Bedakan docs domain di root dengan docs khusus backend. Pindahkan migration tooling ke apps/backend/scripts/migration atau audit semua referensi relatif jika tetap di root.
5. CI: defaults.run.working-directory=apps/backend hanya mengatur run steps. Atur working-directory action Composer secara eksplisit dan cache-dependency-path=apps/backend/package-lock.json untuk setup-node. Perbarui path filters dan workflow changelog sesuai lokasi baru.
6. Jika Compose di infra/compose.yml: build.context=../apps/backend; dockerfile=Dockerfile relatif terhadap context; env_file mengacu lokasi sebenarnya. File .env untuk interpolasi Compose harus dipilih eksplisit dengan --env-file. Audit COPY, bind mounts, nginx root dan volume.
7. Audit scripts/setup.sh, Claude/tool configs, stubs/project, path PHPStan/Pest, Vite, asset publishing, storage symlink dan scheduled/queue commands. Relative path internal backend biasanya tetap berlaku jika dipindahkan bersama.
8. Dari apps/backend jalankan composer install, composer validate, composer check-platform-reqs, npm ci, npm run build, php artisan about, php artisan route:list, vendor/bin/pint --test, php artisan test --compact dan vendor/bin/phpstan analyse --memory-limit=2G. Gunakan database pengujian terpisah. Validasi Docker dengan docker compose config dan smoke test container.
9. Uji login/permission, transaksi purchasing/sales, inventory, posting accounting, printing, queue dan backup/restore sebelum cutover.

Tidak ada perubahan remote, migrasi database, atau pengujian runtime kedua repository dalam review ini. Review ini struktural, bukan audit seluruh logika bisnis.

## Project baru
Generator hanya membuat placeholder direktori dan dokumen; tidak menyalin domain HRIS, dependency, credential, atau kode Laravel. Untuk base generik jangka panjang, siapkan branch/template bersih yang hanya berisi fondasi auth, role, branding dan konfigurasi. feat/pst sudah berisi domain ERP sehingga bukan template generik kosong.

Jangan menyalin aturan khusus HRIS seperti larangan payroll atau larangan feature toggle sebagai kebijakan semua project.
