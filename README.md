# Monorepo Placeholder Kit — PHP / Bash / Python

Tiga implementasi mandiri untuk membuat struktur monorepo berdasarkan susunan 134-hris dan mempertahankan lokasi modul ERP di apps/backend/app-modules.

## Requirements

| Script | Kebutuhan |
|---|---|
| create-project.sh | Bash 3.2+, mkdir, dirname, sort; Git Bash Windows / Linux / macOS |
| create-project.php | PHP CLI 8.1+ |
| create-project.py | Python 3.9+ |

Pilih satu script saja. Tidak saling memanggil. Tidak membutuhkan Composer, npm, Flutter, atau Git untuk membuat placeholder.

## Jalankan lokal

```bash
bash create-project.sh mitra-business --mobile
php create-project.php mitra-business --mobile
python create-project.py mitra-business --mobile
```

Setiap contoh menghasilkan target yang sama. Untuk mencoba ketiganya, gunakan folder/nama berbeda atau hapus hasil uji sendiri terlebih dahulu. Di Windows Python dapat dipanggil dengan `py -3`.

## Jalankan Bash langsung dari GitHub

Generator tersedia di repository public awankumay/create-project pada branch main. Script diletakkan di root repository. Pastikan line endings LF (aturan .gitattributes disertakan).

```bash
curl -fsSL 'https://raw.githubusercontent.com/awankumay/create-project/main/create-project.sh' \
  | bash -s -- mitra-business --mobile
```

Perintah ini mengambil isi script dan menjalankannya melalui stdin; tidak menyimpan script installer atau ZIP ke folder kerja. Folder project hasilnya tetap dibuat di direktori aktif.

Pratinjau tanpa membuat folder:

```bash
curl -fsSL 'https://raw.githubusercontent.com/awankumay/create-project/main/create-project.sh' \
  | bash -s -- mitra-business --mobile --gateway --dry-run
```

Untuk memastikan kegagalan curl diteruskan sebagai status pipeline, jalankan `set -o pipefail` terlebih dahulu di terminal Bash atau script pemanggil. Gunakan URL repository yang Anda kendalikan. Mengganti `main` dengan commit SHA atau tag rilis membuat versi yang dijalankan tetap.

Alternatif memakai variabel agar URL cukup ditulis sekali:

```bash
SCAFFOLD_URL='https://raw.githubusercontent.com/awankumay/create-project/main/create-project.sh'
curl -fsSL "$SCAFFOLD_URL" | bash -s -- mitra-business --mobile --modules core,master-data,purchasing,sales
```

Untuk repository PRIVATE, URL Raw biasa memerlukan autentikasi. Alur contoh di atas ditujukan untuk repository PUBLIC. 

## Opsi yang sama pada semua versi

| Opsi | Fungsi |
|---|---|
| NAME | Wajib; slug huruf kecil, angka dan tanda hubung, diawali huruf |
| --parent PATH | Folder induk tujuan, default direktori aktif |
| --modules LIST | Modul dipisah koma; duplikat dihapus; minimal satu |
| --mobile | Membuat placeholder Flutter |
| --gateway | Membuat placeholder layanan integrasi |
| --dry-run | Menampilkan daftar file tanpa menulis |
| --help | Bantuan |

Default modul: core, master-data, purchasing, sales, inventory, finance, accounting, printing. Untuk menyamai seluruh nama modul ERP yang terlihat di feat/pst, tambahkan hris,rental,requester pada --modules. Gateway bukan keharusan untuk ERP.

```bash
bash create-project.sh mitra-business \
  --parent '/d/Project/MitraSource' \
  --modules core,master-data,purchasing,sales,inventory,finance,accounting,printing,hris,rental,requester \
  --mobile --gateway
```

Untuk PHP/Python di Windows gunakan path yang dikenali runtime tersebut, misalnya `D:/Project/MitraSource`. `/d/...` adalah konvensi path Git Bash.

## Struktur hasil

```text
mitra-business/
  apps/
    backend/
      README.md
      app-modules/
        core/
          src/{Actions,Services,Models,Policies,Filament}/
          database/{migrations,seeders}/
          resources/views/
          routes/
          tests/{Feature,Unit}/
        ...modul lainnya...
    mobile/                 # bila --mobile
      lib/{core,features}/
      test/
    gateway/                # bila --gateway
      cmd/
      internal/
      docs/
  packages/api-contracts/
  infra/production/
  scripts/
  docs/
  .github/workflows/
  AGENTS.md
  README.md
  scaffold.txt
```

Dokumen placeholder meliputi INSTALL, STRUCTURE, DESIGN, SCHEMA, WORKFLOWS, API, SECURITY, TESTING, DECISIONS, DEPLOY dan TODO. Folder kosong diberi .gitkeep.

## Batasan

Hasil ini belum merupakan aplikasi Laravel/Filament/Flutter/Go yang dapat dijalankan. Tidak ada instalasi dependency, download source, inisialisasi Git, database migration, atau penyalinan kode bisnis HRIS. Folder modul belum memiliki composer.json dan provider sehingga belum menjadi package aktif. Baca docs/INSTALL.md pada hasil generator untuk langkah berikutnya.

Target yang sudah ada, termasuk symlink, ditolak. Jika terjadi disk penuh atau kegagalan I/O, target parsial dapat tersisa; periksa sebelum menghapus atau mengulang. Tidak ada overwrite atau cleanup otomatis.

## Validasi paket

- Bash: pemeriksaan sintaks dengan bash -n, eksekusi lokal dan stdin streaming.
- Python: kompilasi sintaks dan eksekusi.
- Bash/Python: file identik untuk empat profil; path ber-spasi, duplikat modul, dry-run, nama invalid, target existing dan symlink diuji.
- PHP: implementasi ditinjau, tetapi lint dan runtime belum diuji karena PHP CLI tidak tersedia di lingkungan pembuat. Jalankan `php -l create-project.php`, lalu gunakan `--dry-run` dan project percobaan sebelum penggunaan.
- Eksekusi Bash dari stdin sudah diuji. URL GitHub Raw mengikuti lokasi script di repository ini.

REVIEW.md memuat hasil review sebelumnya dengan commit sumbernya; paket ini tidak mengambil snapshot branch baru.
