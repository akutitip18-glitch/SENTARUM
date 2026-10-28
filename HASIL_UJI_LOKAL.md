# Uji lokal SENTARUM Tahap 012

- Semua 13 blok JavaScript pada `index.html`: lulus pemeriksaan sintaks Node.js.
- Aplikasi lama tetap merender Dashboard: lulus.
- Panel dibuka dari tombol topbar: lulus.
- Simulasi login Supabase Auth dan pembacaan data: lulus dengan respons mock, 46 katalog/3 indikator/15 target.
- Filter tahun hingga 2029: lulus.
- Password dikosongkan setelah login: lulus.
- Logout mengosongkan identitas sesi di halaman: lulus.
- Menu sinkronisasi JSONB lama disembunyikan pada Settings: lulus.
- Login salah pada lebar 390 px dan 760 px: ditangani tanpa memperlihatkan data.
- Tidak ada `pageerror` JavaScript pada skenario di atas.
- **Belum diuji:** login langsung ke Supabase milik pengguna dari versi 012, kestabilan jaringan, akun lain, database business CRUD nyata, multi-pengguna, dan produksi.
