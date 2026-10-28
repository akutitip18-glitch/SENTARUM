# Keputusan SPJ Individual SENTARUM

Keputusan terbaru menggantikan rancangan kombinasi kolektif/individual sebelumnya:

1. Satu agenda → banyak register perjalanan.
2. Satu register perjalanan (individual atau rombongan) → banyak peserta.
3. **Satu peserta → paling banyak satu SPJ individual per register perjalanan.** Semua rincian dan bukti pertanggungjawaban individual ditambahkan pada SPJ tersebut.
4. Biaya bersama tidak dicatat sebagai SPJ kolektif; bila terdapat bukti bersama, tautkan sebagai evidence register. Setiap nominal hanya dicatat pada SPJ peserta sesuai dokumen pembebanan nyata; jangan membagi biaya bersama secara otomatis.
5. Nilai diajukan, diakui, dibayarkan, dan pengembalian dipisahkan; implementasi 014 baru mencatat nilai diajukan.
6. Penutupan perjalanan tetap memerlukan pemeriksaan seluruh peserta dan SPJ yang diwajibkan, serta evidence dan tindak lanjut. Penerapan otomatis penutupan di server bukan cakupan 014.
7. Data perjalanan/SPJ lama yang belum dikonversi tetap dipertahankan, perlu rekonsiliasi khusus sebelum migrasi produksi.

Pengujian lokal: browser Chromium dengan respons Supabase simulasi; operasi register, peserta, SPJ individu, biaya, evidence, tindak lanjut lulus tanpa JavaScript error. **Migration SQL belum diuji pada database pengguna**.
