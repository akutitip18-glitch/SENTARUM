# SENTARUM — Kandidat Terpadu v0.27.0 (STAGING)

**Satu paket untuk pengujian full-stack bertahap, bukan produksi aktif.**

Isi utama:
- `SENTARUM_015_016_EVIDENCE_RENSTRA_STAGING.sql`: satu SQL / satu Run setelah 014 SPJ individu terpasang; memasang kebijakan penyimpanan file privat, registrasi file yang diaudit, usulan capaian dan kontribusi Renstra, dan checklist data perjalanan yang tidak mengesahkan penutupan.
- `index.html`: pengganti file di GitHub/Cloudflare Pages situs staging. Mempertahankan aplikasi lama beserta panel server 012/013/014 dan menambah `☁ Pusat Kerja`.
- `PANDUAN_SEKALI_JALAN.md`: langkah sangat singkat bagi admin nonteknis.
- `UAT_DAN_GO_NO_GO.md`: skenario verifikasi dan syarat produksi.
- `PRATINJAU_PONSEL.png`, `PRATINJAU_DESKTOP.png`: hasil render UI dengan API simulasi, **bukan hasil server asli**.
- `test_ui_local.py`: pengujian browser dengan mock API; hanya untuk dokumentasi pengembang.
- `stage015_workspace.html`: sumber komponen tambahan agar pembaruan berikutnya tidak perlu mengedit file HTML secara acak.

## Penting sebelum memasang

1. Jangan gunakan proyek produksi; hanya `sentarum-staging`.
2. Pastikan SQL 014 **versi SPJ individual** sudah tercatat sebagai migrasi ke-12. SQL 015/016 akan menolak jika bukan itu kondisinya.
3. Jangan ulang SQL 001–014.
4. SQL 015/016 belum diuji pada PostgreSQL nyata di proyek Anda; uji sintaks lokal hanya meliputi JavaScript dan simulasi browser.
5. Jangan memasukkan data resmi/pegawai nyata atau dokumen sensitif untuk UAT awal.

## Jangkauan integrasi

- Register generik di `☁ Data Server` menggunakan metadata formulir yang cocok dari prototipe, termasuk draf, revisi, arsip, dan tautan data. **Bukan berarti seluruh modul sudah menjadi tabel relasional typed khusus.**
- Perjalanan/SPJ individual via `☁ Perjalanan Server` menggunakan tabel typed dan RPC Tahap 014.
- Evidence privat menggunakan Supabase Storage dengan RLS, checksum file, metadata dan pilihan tautan register/SPJ.
- Renstra 2025–2029: target, usulan actual ber-evidence, dan usulan kontribusi kegiatan. **Tidak mengklaim realisasi terverifikasi.**
- Checklist perjalanan: baca kondisi server dan jelaskan kekurangan, **bukan tombol penutupan resmi**.

## Keputusan GO/NO-GO

**GO untuk UAT staging**, **NO-GO untuk penggunaan produksi** sampai seluruh gerbang keamanan dan migrasi historis selesai.
