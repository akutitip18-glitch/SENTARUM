# SENTARUM — GitHub Pages Staging (Tahap 010)

## File yang diunggah

**Unggah `index.html` ke root repository GitHub.** Project URL dan publishable key Anda sudah tertanam di dalamnya; Anda tidak perlu mengisinya saat login.

Project URL: `https://twwadofupxcupmjzdbgj.supabase.co`

Kunci yang dipasang: **publishable key** (`sb_publishable_...`), aman untuk kode klien; **jangan** memasukkan secret key, service role, token, atau password database.

## Cara deploy tanpa Terminal

1. Buka GitHub → repository SENTARUM untuk **staging** (atau buat repository terpisah `sentarum-staging`).
2. Pilih **Add file → Upload files** → pilih `index.html` → **Commit changes**.
3. Buka **Settings → Pages**; pada Source pilih **Deploy from a branch**, Branch `main`, folder `/(root)`, kemudian **Save**.
4. Buka URL GitHub Pages yang ditampilkan di Settings → Pages.
5. Akun `admin@sentarum.go.id` sudah terisi otomatis; masukkan **hanya password** akun staging dan klik **Uji login dan hak baca**.
6. Salin ringkasan hasil melalui tombol pada halaman; kirim ringkasan saja, tanpa password/token.

## Apa yang diuji

- Data modul tidak dibuka bagi pengunjung anonim.
- Email dan password Admin diterima Supabase Auth.
- Admin dapat membaca 46 katalog modul dan 15 target tahunan Renstra sesuai kebijakan tahap 009.
- Data SPJ tetap tertutup pada tahap ini.

## Penting: apa yang BELUM dikerjakan

`index.html` saat ini adalah **portal uji login dan izin baca staging**, bukan full aplikasi SENTARUM v0.25.6 yang sudah tersambung ke database. Versi v0.25.6 masih memiliki penyimpanan prototipe di browser dan sinkronisasi cloud JSON lama yang tidak sesuai skema SQL 001–009. Jangan mengunggah data instansi atau menganggap data dari prototipe sudah ada di Supabase.

Karena GitHub Pages bersifat situs statis publik, seluruh isi HTML dan publishable key dapat dilihat pengunjung. Keamanan **data** bergantung pada autentikasi, GRANT, dan RLS di Supabase. Login pada halaman ini bukan perlindungan untuk kode publik di GitHub Pages.

## Jika login gagal

Jika muncul `Email not confirmed` / `Invalid login credentials`, periksa status akun di Supabase Authentication → Users. Jangan menonaktifkan keamanan email untuk seluruh pengguna hanya demi mengatasi akun dummy.

## URL pengalihan

Login email/password ini tidak menggunakan OAuth/magic link sehingga tidak memerlukan redirect tambahan untuk pengujian. Saat fitur undangan, pemulihan password atau OAuth diaktifkan, atur alamat Pages yang tepat pada Supabase Authentication → URL Configuration.
