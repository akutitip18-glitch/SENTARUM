# SENTARUM Staging — Tahap 012 (Integrasi Awal ke Aplikasi Utama)

## Status dari Tahap 011

Berdasarkan hasil yang dikirim pengguna, tes melalui GitHub Pages lulus untuk autentikasi Admin dan CRUD pada `sentarum_admin_sandbox`, dan akses SPJ masih ditolak. SQL tahap 001–011 **tidak perlu dijalankan ulang**.

## Apa isi file `index.html` ini?

1. Aplikasi lengkap SENTARUM v0.25.6 UX-First/Model B masih ada sebagai prototipe operasional lokal.
2. Ditambahkan tombol **☁ Renstra Supabase** pada bar atas.
3. Tombol tersebut membuka panel login Admin dan mengambil **langsung dari Supabase Staging**: katalog modul, periode Renstra, indikator, dan target tahunan.
4. Email Admin, URL proyek, dan publishable key telah dimasukkan sebelumnya; operator hanya memasukkan password ketika masuk.
5. **Hanya pembacaan data server.** Tidak ada fitur tulis target, SPJ, Perjalanan Dinas, atau dokumen.
6. Menu konfigurasi sinkronisasi Supabase JSONB prototipe lama disembunyikan di tampilan staging, karena tidak kompatibel dengan skema database 001–011.
7. Password tidak ditulis ke localStorage; JWT tidak dicetak ke layar dan hanya berada di memori tab saat halaman hidup. Keluar dari panel melepaskan sesi dari halaman.

## Yang perlu dilakukan sekarang (tanpa Terminal dan tanpa SQL)

1. Masuk ke repository GitHub yang sudah digunakan untuk Tahap 011.
2. Ganti file `index.html` di **root repository** dengan file `index.html` dari paket ini, lalu **Commit changes**.
3. Buka GitHub Pages; lakukan *refresh* jika masih menampilkan versi lama.
4. Di kanan atas aplikasi, klik tombol **☁ Renstra Supabase**.
5. Masukkan password akun Admin, lalu klik **Masuk & Baca Data**.
6. Pastikan status terhubung menampilkan jumlah dari server: **46 modul, 3 indikator, 15 target tahunan**.
7. Ubah pilihan tahun dari 2025 hingga 2029 dan periksa apakah target muncul.
8. Kirim **ringkasan hasil** saja ke ChatGPT. Jangan kirim password atau token.

## Batasan yang wajib diketahui

- **Formulir SENTARUM lainnya masih menyimpan data di localStorage**, bukan Supabase. Jangan gunakan input lokal sebagai catatan resmi atau memasukkan data sensitif instansi.
- Data dashboard Renstra ini berasal dari **Rancangan Akhir Renstra**, dan realisasi belum diisi. Target tidak sama dengan capaian.
- Tampilan memang menggunakan publishable key untuk browser, **bukan** secret/service role key.
- Uji browser lokal telah dilakukan dengan **respons Supabase simulasi**, bukan koneksi nyata ke server pengguna. Pengujian nyata baru terjadi setelah GitHub Pages diunggah dan pengguna login.
- Pengamanan produksi, audit end-to-end, pemulihan akses, penyimpanan evidence, dan server CRUD untuk semua modul belum selesai.

## Tahap setelah 012 lulus

Tahap 013 akan menguji **satu modul operasional end-to-end** di database server menggunakan akun Admin, kebijakan RLS, data simulasi, dan audit server; desain repository dan izin harus divalidasi sebelum membuka hak tulis tabel bisnis.

## Konfigurasi publik yang tertanam

- URL: `https://twwadofupxcupmjzdbgj.supabase.co`
- Key: publishable key yang sudah diberikan pengguna (bukan kredensial rahasia)
- Akun tampilan awal: `admin@sentarum.go.id`

## Jika terjadi masalah

- **HTTP 401 pada login:** cek password atau status Auth.
- **HTTP 403 / 401 setelah login:** periksa kebijakan RLS/GRANT SQL 009 yang telah diuji; jangan membuka akses anonim.
- **Jumlah target bukan 15:** periksa data Renstra di server. Jangan membuat target tambahan untuk mengejar angka.
- **Halaman masih “Tahap 011”:** periksa commit pada `index.html` root dan deployment GitHub Pages.
