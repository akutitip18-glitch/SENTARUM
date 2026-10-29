# Gerbang UAT dan Produksi — SENTARUM Kandidat Terpadu

## Lingkup verifikasi

| Kelompok | Skenario minimum | Kriteria GO |
|---|---|---|
| Authentication | Admin login, logout, sesi kedaluwarsa, email dummy recovery | Akun dapat dipulihkan tanpa akses ilegal |
| RLS | Anonymous, Operator beda unit, Admin; SELECT/INSERT/UPDATE RPC | Data yang bukan kewenangannya ditolak server |
| General CRUD | Create draf, validasi aktif, update revisi, arsip, relasi | Tidak hilang data; relasi dan audit konsisten |
| Perjalanan | Agenda→register→peserta, perubahan peserta, pembatalan | Relasi benar, perubahan berjejak |
| SPJ | Dua peserta dalam satu perjalanan; satu SPJ per individu | Ganda/lintas peserta ditolak; total tidak digandakan |
| Evidence | PDF kecil, unduh privat, error upload, file terlarang, akses anonim | Tanpa URL publik dan tanpa akses silang; hash tercatat |
| Renstra | Target 2025–2029, usulan actual, evidence, mapping | Usulan tidak tampil sebagai capaian terverifikasi |
| Penutupan | Perjalanan belum terlaksana, SPJ kosong, tindak lanjut terbuka | Tidak ada penutupan otomatis; kekurangan jelas |
| Multi-pengguna | Dua pengguna mengubah record sama | Nomor revisi mencegah overwrite |
| Migrasi legacy | Backup browser, mapping ID, rekonsiliasi biaya & evidence | Tidak ada relasi rusak / nilai hilang |
| Backup–restore | Restore data PostgreSQL dan file Storage | RTO/RPO disetujui instansi dan uji restore lulus |
| Operasional | Ponsel, MacBook, waktu input, aksesibilitas, dukungan | Waktu kerja turun dan operator menyetujui alur |

## Keputusan saat paket disusun

- **GO** untuk memasang SQL 015/016 pada staging jika prasyarat 014 terpenuhi dan menjalankan UAT.
- **NO-GO** untuk membuka data resmi, mengaktifkan hak Operator massal, maupun mengganti proyek produksi.

## Referensi otoritatif

- Supabase Production Checklist: https://supabase.com/docs/guides/deployment/going-into-prod
- Supabase Storage Access Control: https://supabase.com/docs/guides/storage/security/access-control
- Supabase Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security
