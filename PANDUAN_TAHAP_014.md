# SENTARUM — Tahap 014 SPJ Individual Per Peserta

**Khusus:** Supabase `sentarum-staging`; **bukan produksi**. Berdasarkan permintaan akhir: SPJ **tiap individu**, termasuk perjalanan rombongan. Rancangan lama SPJ kolektif/campuran **tidak digunakan** untuk Tahap 014 ini.

## Prasyarat

- SQL 001–009, 011, 013 sudah lulus. Jumlah catatan migrasi yang diharapkan sebelum Tahap 014 = **11**; jumlah tabel publik = **28**; semua RLS dan trigger audit tetap aktif.
- Login Admin pada aplikasi staging bekerja; bucket `sentarum-evidence-staging` berstatus privat.
- **Belum ada isi** pada `spj_packages`, `spj_cost_lines`, atau `spj_participant_coverage`; SQL berhenti jika sudah ada, agar data historis tidak diklasifikasikan ulang sembarangan.
- Proyek yang benar adalah `sentarum-staging`. Jangan unggah atau masukkan data resmi dulu.

## Cara memasang (satu SQL, satu index)

1. Buka Supabase Dashboard → proyek `sentarum-staging` → **SQL Editor → New query**.
2. Salin seluruh isi `SENTARUM_014_SPJ_INDIVIDUAL_SEKALI_RUN.sql`; **Run satu kali**. Jangan menjalankan SQL 014 versi kolektif/campuran.
3. Jika muncul error, jangan ulangi atau unggah HTML. Kirim pesan error untuk diperiksa.
4. Jika berhasil, ganti **`index.html`** pada repository/deploy yang menerbitkan `sentarum.pages.dev`, tunggu deploy aktif.
5. Buka aplikasi → **☁ Renstra Supabase** untuk login Admin → **☁ Data Server**. Bila agenda contoh sebelumnya telah diarsipkan, buat **Agenda simulasi baru** dan pilih **Simpan sebagai register aktif**, bukan hanya draf.
6. Buka **☁ Perjalanan Server** → buat perjalanan rombongan, tambahkan dua peserta simulasi, lalu buat SPJ **masing-masing peserta**. Tambahkan satu rincian biaya pada setiap SPJ. Lihat total yang dijumlahkan per individu.
7. Bila ada dokumen di **Data Server** dan aktif, Anda boleh menautkannya sebagai evidence ke register/peserta/SPJ. *Unggah file privat belum tersedia pada tahap ini.*

## Hasil SQL yang diharapkan

| Kolom | Target bila belum ada data Model B |
|---|---|
| status | `LULUS_014_SPJ_INDIVIDUAL` |
| migrasi_tercatat | 12 |
| kebijakan_baca_model_b | 8 |
| tabel_tanpa_rls | 0 |
| anonim_bisa_baca_perjalanan | false |
| login_bisa_tulis_biaya_langsung | false |
| perjalanan_tersimpan | 0 |
| spj_tersimpan | 0 |
| aturan_spj_individual | 3 |

Catatan: nilai 0 untuk perjalanan/SPJ mengasumsikan belum ada data bisnis Model B sebelumnya; SQL tidak menghapus catatan sungguhan. Pengujian internal di SQL memakai transaksi yang dibatalkan pada savepoint sebelum commit.

## Pengaman utama

- Pemasukan SPJ dilakukan melalui RPC satu transaksi dengan peserta terpilih; cakupan dibuat otomatis.
- `spj_packages.participant_id` wajib dan harus menunjuk peserta di perjalanan yang sama.
- Indeks unik melarang dua SPJ untuk peserta yang sama pada perjalanan yang sama.
- Rincian `spj_cost_lines` wajib bersifat individual dan pemiliknya harus sama dengan `spj_packages.participant_id`; ada constraint dan trigger di database.
- Evidence rombongan dapat ditautkan ke **register** sebagai referensi, tetapi tidak otomatis menjadi nominal biaya pada SPJ setiap peserta.
- Nilai biaya baru **diajukan**; belum diakui, belum dibayar, tidak membuktikan pencairan.
- Akses baca dibatasi ke Admin aktif organisasi, tulis bisnis melalui fungsi berizin; RLS tetap aktif. Login dan pembatasan yang lebih menyeluruh, file privat, pembayaran, otorisasi pejabat, backup-restore, dan UAT multi-pengguna tetap belum selesai.

## Batasan penting

Aplikasi HTML lama yang ada di belakang panel masih menyimpan sebagian modul secara **lokal**. Gunakan panel **☁ Perjalanan Server** untuk pengujian Model B baru. Belum ada migrasi otomatis data lokal. Jangan menganggap Tahap 014 sebagai deploy produksi atau sinkronisasi semua modul.
