# SENTARUM v0.27.0 — Paket Kandidat Terpadu (STAGING)

**Lingkungan:** proyek Supabase `sentarum-staging` dan situs pengujian `sentarum.pages.dev`. **Bukan rilis produksi.** Tanggal paket: 29 Oktober 2026.

## Keputusan desain yang dipertahankan

- **Pegawai dibantu aplikasi:** input inti dulu, draf, relasi data sumber, peringatan yang jelas.
- Perjalanan Dinas dapat individual/rombongan. **SPJ wajib per individu**, satu SPJ untuk setiap peserta pada satu register perjalanan. Tidak ada SPJ kolektif dalam proses baru.
- Agenda, dokumen, data induk, dan register umum tersimpan melalui `☁ Data Server` (RPC server 013). Modul operasional Model B memakai `☁ Perjalanan Server` (RPC server 014).
- Satu dokumen dapat digunakan sebagai tautan evidence, tanpa menduplikasi file. File sesungguhnya disimpan privat di Supabase Storage.
- Periode Renstra 2025–2029, baseline 2024. Target yang dimasukkan sebelumnya berasal dari **Rancangan Akhir**, sehingga belum boleh disebut target Renstra yang disahkan.
- Usulan realisasi **belum terverifikasi** hingga dilakukan telaah dan pengesahan oleh petugas/pejabat berwenang.
- Riwayat/audit server aktif; simpan data tidak sama dengan menyetujui dokumen.

## Petunjuk cepat — cukup dua pekerjaan teknis

**A. SQL satu kali.** Masuk Supabase Dashboard → `sentarum-staging` → **SQL Editor → New query**. Buka file `SENTARUM_015_016_EVIDENCE_RENSTRA_STAGING.sql`, salin keseluruhan, klik **Run satu kali**. SQL melakukan prasyarat (Tahap 014, 12 catatan, RLS, bucket privat dan Admin), memasang kebijakan storage dan fungsi terbatas, lalu mencatat dua migration dalam satu transaksi. Jika error: **berhenti** dan kirim pesan error, jangan jalankan berulang.

Hasil target:

| Kolom | Target |
|---|---|
| `status` | `SIAP_UJI_015_016` |
| `migrasi_tercatat` | `14` |
| `tabel_tanpa_rls` | `0` |
| `kebijakan_storage_admin` | `2` |
| `kebijakan_metadata` | `1` |
| `anon_bisa_baca_metadata` | `false` |
| `login_bisa_ubah_spj_langsung` | `false` |

**B. Perbarui situs staging.** **Hanya jika SQL sukses**, unggah file `index.html` baru ke sumber deploy yang menerbitkan `sentarum.pages.dev`, commit/publish, dan segarkan browser. Tombol baru `☁ Pusat Kerja` muncul di bagian atas. URL Supabase/publishable key sudah tertanam. Jangan memasukkan password atau token ke file.

## Uji penerimaan di situs

1. Klik `☁ Renstra Supabase`, login Admin yang ada. Buka `☁ Pusat Kerja`.
2. Buka tab **Evidence privat**; unggah **satu PDF simulasi** kecil (tanpa data pribadi). Pastikan berkas tampil dalam daftar. Klik **Buka privat** dan pastikan file terbuka melalui tautan terbatas 60 detik. Jangan pernah mengaktifkan Public Bucket.
3. Buka tab **Capaian Renstra**, tahun 2026. Pastikan 3 indikator terbaca. Ajukan nilai simulasi dan pilih dokumen yang baru diunggah. Pastikan ditandai **dalam verifikasi**, bukan terverifikasi. Setelah uji, nilai simulasi perlu dibersihkan/rekonsiliasi oleh Admin melalui prosedur database terkontrol; jangan gunakan data resmi.
4. Buka `☁ Data Server`; coba baca modul generik dan pastikan draf tersimpan dari server (modul Perjalanan/SPJ khusus melalui menu tersendiri).
5. Buka `☁ Perjalanan Server` dan periksa bahwa SPJ tetap **satu per peserta**. Jangan membuat biaya bersama sebagai SPJ peserta lain.
6. Buka tab **Checklist perjalanan**, pilih register simulasi dan klik Periksa. Data kekurangan muncul, tetapi tidak ada penutupan otomatis.
7. Coba akses tanpa login dan akun non-Admin: data, file privat, dan fungsi tulis harus ditolak. **Uji tersebut belum dilaksanakan pada proyek Anda pada saat paket ini disusun.**

## Batasan yang harus diketahui

- **Formulir prototipe lama yang terlihat di belakang panel masih memakai penyimpanan lokal.** Gunakan `☁ Data Server` untuk record generik, `☁ Perjalanan Server` untuk Model B, `☁ Pusat Kerja` untuk dokumen privat dan data Renstra. Tidak ada klaim bahwa setiap tombol lama sudah menulis ke Supabase.
- Pusat Kerja mendukung katalog/field generik yang kompatibel, namun tidak otomatis mengubah semua 46 modul menjadi tabel typed khusus. Modul perencanaan/keuangan yang memerlukan aturan tersendiri harus melewati UAT domain dan pemetaan master.
- Unggah file dan registrasi metadata **tidak satu transaksi atomik** karena Storage terpisah dari PostgreSQL; bila gagal sebagian, panel menampilkan peringatan untuk pemeriksaan/rekonsiliasi. Jangan mencoba menghapus berkas secara sembarang.
- SQL 015/016 tidak membuka akses CRUD SPJ secara langsung, tidak mengesahkan pembayaran, tidak memverifikasi bukti, dan tidak menutup perjalanan secara resmi.
- Masih **NO-GO PRODUKSI** sampai hak akses Operator multiunit, UAT pegawai, seluruh integrasi modul, data historis, Security Advisor, uji backup-restore termasuk berkas, pemulihan akun dummy, serta pengesahan dokumen/aturan dilakukan.
- Jangan menjalankan ulang SQL 001–014 atau menggunakan SQL 014 campuran yang lama. Untuk produksi gunakan proyek Supabase terpisah dan mekanisme migration berversi setelah audit.

## Bukti pengujian lokal

Pemeriksaan sintaks JavaScript pada semua blok HTML: **lulus**. Simulasi browser dengan respons API buatan untuk login yang telah tersedia, unggah file, registrasi metadata, usulan realisasi Renstra, dan checklist: **lulus**, tanpa error JavaScript. **Tidak setara dengan bukti SQL atau Storage nyata**; hasil dari Supabase Anda tetap diperlukan.
