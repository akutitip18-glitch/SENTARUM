-- SENTARUM STAGING 015 + 016 — INTEGRASI EVIDENCE PRIVAT / RENSTRA / KELAYAKAN
-- Jalankan hanya pada sentarum-staging setelah SQL 014 SPJ INDIVIDUAL lulus.
-- Satu transaksi / satu kali Run. BUKAN migrasi produksi.
-- SQL 001–014 JANGAN dijalankan ulang.
BEGIN;
SET LOCAL statement_timeout='120s';

DO $preflight$
DECLARE v_step integer;v_bad integer;v_bucket integer;v_adm integer;
BEGIN
  SELECT count(*) INTO v_step FROM private.sentarum_manual_migrations;
  SELECT count(*) INTO v_bad FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','p') AND NOT c.relrowsecurity;
  SELECT count(*) INTO v_bucket FROM storage.buckets
    WHERE id='sentarum-evidence-staging' AND public=false;
  SELECT count(*) INTO v_adm FROM public.memberships m
    JOIN public.user_profiles p ON p.user_id=m.user_id
    JOIN public.organizations o ON o.id=m.org_id
    JOIN auth.users a ON a.id=m.user_id
    WHERE lower(a.email)='admin@sentarum.go.id' AND o.code='SETWAN_KAPUAS_HULU'
      AND m.role_code='admin_aplikasi' AND m.active AND p.is_active
      AND m.valid_from<=current_date AND (m.valid_until IS NULL OR m.valid_until>=current_date);
  IF v_step<>12 OR v_bad<>0 OR v_bucket<>1 OR v_adm<>1 THEN
    RAISE EXCEPTION 'STOP: syarat staging belum tepat (migrasi %, tanpa RLS %, bucket privat %, admin aktif %). Target 12/0/1/1.',v_step,v_bad,v_bucket,v_adm;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM private.sentarum_manual_migrations
    WHERE migration_id='20261029001401_model_b_individual_admin_rpc_staging_v1') THEN
    RAISE EXCEPTION 'STOP: SQL 014 Individual belum tercatat'; END IF;
  IF EXISTS(SELECT 1 FROM private.sentarum_manual_migrations
    WHERE migration_id IN ('20261029001501_evidence_private_staging_v1','20261029001601_renstra_readiness_staging_v1')) THEN
    RAISE EXCEPTION 'STOP: SQL 015 atau 016 sudah pernah dipasang. Jangan ulang.'; END IF;
  IF to_regprocedure('public.sentarum_attach_private_file(uuid,uuid,text,text,text,text)') IS NOT NULL THEN
    RAISE EXCEPTION 'STOP: fungsi unggah metadata sudah ada.'; END IF;
  IF has_table_privilege('anon','public.document_assets','SELECT') OR
     has_table_privilege('authenticated','public.document_assets','INSERT') THEN
    RAISE EXCEPTION 'STOP: privilege document_assets tidak sesuai baseline.'; END IF;
END;
$preflight$;

-- 015: EVIDENCE PRIVAT. Bucket yang sudah ada tetap privat.
-- Hanya Admin aktif untuk organisasi pada segmen pertama lokasi file.
-- Bentuk nama file: <org-uuid>/<doc-record-uuid>/<file-uuid>.<ext>
-- Tidak ada izin UPDATE/DELETE storage.objects, tidak ada public URL.
CREATE POLICY sentarum_015_evidence_admin_select ON storage.objects
  FOR SELECT TO authenticated USING (
    bucket_id='sentarum-evidence-staging'
    AND name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|png|jpg|jpeg|webp)$'
    AND public.sentarum_is_org_admin(
      CASE WHEN name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
       THEN split_part(name,'/',1)::uuid ELSE NULL END)
  );
CREATE POLICY sentarum_015_evidence_admin_insert ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (
    bucket_id='sentarum-evidence-staging'
    AND name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|png|jpg|jpeg|webp)$'
    AND public.sentarum_is_org_admin(
      CASE WHEN name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
       THEN split_part(name,'/',1)::uuid ELSE NULL END)
    AND EXISTS (
      SELECT 1 FROM public.business_records d
      WHERE d.id=(CASE WHEN name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/'
                    THEN split_part(name,'/',2)::uuid ELSE NULL END)
        AND d.org_id=(CASE WHEN name ~ '^[0-9a-f-]{36}/'
                         THEN split_part(name,'/',1)::uuid ELSE NULL END)
        AND d.module_key='dokumen' AND d.state='active'
    )
  );

GRANT SELECT ON public.document_assets TO authenticated;
CREATE POLICY sentarum_015_document_asset_admin_read ON public.document_assets
 FOR SELECT TO authenticated USING(public.sentarum_is_org_admin(org_id));

-- Metadata tidak diterima sebelum file benar-benar ada di bucket privat.
CREATE FUNCTION public.sentarum_attach_private_file(
 p_org_id uuid,p_document_record_id uuid,p_path text,p_filename text,
 p_classification text,p_sha256 text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v_uid uuid; v_id uuid; v_metadata jsonb; v_owner text;
BEGIN
 v_uid:=auth.uid();
 IF v_uid IS NULL OR NOT public.sentarum_is_org_admin(p_org_id) THEN
    RAISE EXCEPTION 'Admin aktif diperlukan' USING ERRCODE='42501'; END IF;
 IF p_document_record_id IS NULL OR NOT EXISTS(
    SELECT 1 FROM public.business_records b
    WHERE b.id=p_document_record_id AND b.org_id=p_org_id
      AND b.module_key='dokumen' AND b.state='active') THEN
    RAISE EXCEPTION 'Dokumen aktif organisasi belum terdaftar'; END IF;
 IF p_path IS NULL OR p_path !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|png|jpg|jpeg|webp)$'
    OR split_part(p_path,'/',1)<>p_org_id::text
    OR split_part(p_path,'/',2)<>p_document_record_id::text THEN
    RAISE EXCEPTION 'Lokasi file tidak sesuai organisasi / ID dokumen'; END IF;
 IF p_filename IS NULL OR length(btrim(p_filename))<1 OR length(p_filename)>180
    OR strpos(p_filename,'/')>0 OR strpos(p_filename,chr(92))>0 THEN
    RAISE EXCEPTION 'Nama berkas tidak valid'; END IF;
 IF p_classification NOT IN ('internal','restricted') THEN
    RAISE EXCEPTION 'Klasifikasi harus internal/restricted'; END IF;
 IF p_sha256 IS NULL OR p_sha256 !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'Checksum SHA-256 wajib'; END IF;
 SELECT o.metadata,o.owner_id INTO v_metadata,v_owner
 FROM storage.objects o WHERE o.bucket_id='sentarum-evidence-staging' AND o.name=p_path;
 IF NOT FOUND OR v_owner IS DISTINCT FROM v_uid::text THEN
    RAISE EXCEPTION 'File privat belum diunggah oleh akun login ini'; END IF;
 IF coalesce(v_metadata->>'mimetype','') NOT IN
      ('application/pdf','image/jpeg','image/png','image/webp') THEN
    RAISE EXCEPTION 'Format file tidak diizinkan'; END IF;
 IF coalesce(v_metadata->>'size','') !~ '^[0-9]+$' OR
     (v_metadata->>'size')::bigint>10485760 OR (v_metadata->>'size')::bigint=0 THEN
    RAISE EXCEPTION 'File harus 1 byte hingga 10 MB'; END IF;
 INSERT INTO public.document_assets(org_id,record_id,storage_bucket,storage_path,
   filename,sha256,classification,uploaded_by)
 VALUES (p_org_id,p_document_record_id,'sentarum-evidence-staging',p_path,
   p_filename,p_sha256,p_classification,v_uid) RETURNING id INTO v_id;
 RETURN v_id;
END;
$fn$;
REVOKE ALL ON FUNCTION public.sentarum_attach_private_file(uuid,uuid,text,text,text,text)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sentarum_attach_private_file(uuid,uuid,text,text,text,text)
 TO authenticated;

INSERT INTO private.sentarum_manual_migrations(migration_id,description)
VALUES ('20261029001501_evidence_private_staging_v1',
 'Private storage RLS Admin; dokumen metadata berbasis file nyata, checksum, referensi satu sumber, tanpa izin hapus');

-- 016: RENSTRA: realisasi hanya USULAN, belum verifikasi / keputusan resmi.
CREATE FUNCTION public.sentarum_renstra_propose_actual(
 p_org_id uuid,p_target_id uuid,p_actual numeric,p_evidence_record_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v_uid uuid;v_target public.renstra_annual_targets%ROWTYPE;
BEGIN
 v_uid:=auth.uid();
 IF v_uid IS NULL OR NOT public.sentarum_is_org_admin(p_org_id) THEN
   RAISE EXCEPTION 'Admin aktif diperlukan' USING ERRCODE='42501'; END IF;
 IF p_actual IS NULL OR p_actual<0 OR p_actual>1000000000 THEN
   RAISE EXCEPTION 'Nilai realisasi tidak valid'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.business_records b
   JOIN public.document_assets a ON a.record_id=b.id AND a.org_id=b.org_id
   WHERE b.id=p_evidence_record_id AND b.org_id=p_org_id
     AND b.module_key='dokumen' AND b.state='active') THEN
   RAISE EXCEPTION 'Pilih dokumen bukti aktif yang telah memiliki berkas privat'; END IF;
 SELECT * INTO v_target FROM public.renstra_annual_targets
 WHERE id=p_target_id AND org_id=p_org_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Target Renstra tidak tersedia'; END IF;
 IF v_target.actual_status='terverifikasi' THEN
    RAISE EXCEPTION 'Realisasi terverifikasi tidak dapat ditimpa dengan usulan baru'; END IF;
 UPDATE public.renstra_annual_targets
 SET actual_numeric=p_actual, actual_status='dalam_verifikasi',
     actual_evidence_record_id=p_evidence_record_id,
     actual_verified_by=NULL,actual_verified_at=NULL
 WHERE id=p_target_id AND org_id=p_org_id;
 RETURN jsonb_build_object('id',p_target_id,'year',v_target.year,
   'actual',p_actual,'state','dalam_verifikasi');
END;
$fn$;
REVOKE ALL ON FUNCTION public.sentarum_renstra_propose_actual(uuid,uuid,numeric,uuid)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sentarum_renstra_propose_actual(uuid,uuid,numeric,uuid)
 TO authenticated;

CREATE FUNCTION public.sentarum_renstra_link_contribution(
 p_org_id uuid,p_target_id uuid,p_record_id uuid,p_explanation text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v_uid uuid;v_target public.renstra_annual_targets%ROWTYPE; v_id uuid;
BEGIN
 v_uid:=auth.uid();
 IF v_uid IS NULL OR NOT public.sentarum_is_org_admin(p_org_id) THEN
   RAISE EXCEPTION 'Admin aktif diperlukan' USING ERRCODE='42501'; END IF;
 IF p_record_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.business_records b
    WHERE b.id=p_record_id AND b.org_id=p_org_id AND b.state='active'
       AND b.module_key NOT IN ('dokumen','spj','peserta_perjadin')) THEN
   RAISE EXCEPTION 'Pilih kegiatan/agenda yang aktif, bukan dokumen/SPJ'; END IF;
 IF p_explanation IS NULL OR length(btrim(p_explanation))<5 OR length(p_explanation)>1500 THEN
   RAISE EXCEPTION 'Penjelasan kontribusi 5–1500 karakter'; END IF;
 SELECT * INTO v_target FROM public.renstra_annual_targets
    WHERE id=p_target_id AND org_id=p_org_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Target Renstra tidak ditemukan'; END IF;
 IF EXISTS(SELECT 1 FROM public.renstra_contributions
   WHERE indicator_id=v_target.indicator_id AND year=v_target.year
     AND record_id=p_record_id) THEN
   RAISE EXCEPTION 'Kontribusi yang sama sudah pernah ditautkan'; END IF;
 INSERT INTO public.renstra_contributions(org_id,renstra_id,year,indicator_id,
   record_id,contribution_kind,mapping_status,explanation)
 VALUES(p_org_id,v_target.renstra_id,v_target.year,v_target.indicator_id,
   p_record_id,'pendukung','usulan',p_explanation) RETURNING id INTO v_id;
 RETURN v_id;
END;
$fn$;
REVOKE ALL ON FUNCTION public.sentarum_renstra_link_contribution(uuid,uuid,uuid,text)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sentarum_renstra_link_contribution(uuid,uuid,uuid,text)
 TO authenticated;

-- Pemeriksaan kelayakan: MENUNJUKKAN KEKURANGAN, TIDAK MENUTUP REGISTER.
CREATE FUNCTION public.sentarum_travel_readiness(p_org_id uuid,p_travel_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v_p int;v_s int;v_unmatched int;v_empty_spj int;v_evidence int;v_pending int;
        v_execution text;
BEGIN
 IF auth.uid() IS NULL OR NOT public.sentarum_is_org_admin(p_org_id) THEN
   RAISE EXCEPTION 'Admin aktif diperlukan' USING ERRCODE='42501'; END IF;
 SELECT status INTO v_execution FROM public.travel_registers
 WHERE id=p_travel_id AND org_id=p_org_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Register perjalanan tidak ditemukan'; END IF;
 SELECT count(*) INTO v_p FROM public.travel_participants
  WHERE travel_id=p_travel_id AND org_id=p_org_id AND status<>'Dibatalkan';
 SELECT count(*) INTO v_s FROM public.spj_packages
  WHERE travel_id=p_travel_id AND org_id=p_org_id;
 SELECT count(*) INTO v_unmatched FROM public.travel_participants p
  WHERE p.travel_id=p_travel_id AND p.org_id=p_org_id AND p.status<>'Dibatalkan'
    AND NOT EXISTS(SELECT 1 FROM public.spj_packages s
      WHERE s.org_id=p.org_id AND s.travel_id=p.travel_id AND s.participant_id=p.id);
 SELECT count(*) INTO v_empty_spj FROM public.spj_packages s
  WHERE s.travel_id=p_travel_id AND s.org_id=p_org_id
    AND NOT EXISTS(SELECT 1 FROM public.spj_cost_lines c
      WHERE c.org_id=s.org_id AND c.spj_id=s.id);
 SELECT count(*) INTO v_evidence FROM public.travel_evidence_links
  WHERE travel_id=p_travel_id AND org_id=p_org_id;
 SELECT count(*) INTO v_pending FROM public.travel_followups
  WHERE travel_id=p_travel_id AND org_id=p_org_id
   AND state IN ('Terbuka','Dalam proses');
 RETURN jsonb_build_object('status','PERLU_TELAAH_ADMINISTRATIF',
   'pelaksanaan',v_execution,'peserta_aktif',v_p,'spj_tercatat',v_s,
   'peserta_tanpa_spj',v_unmatched,'spj_tanpa_rincian',v_empty_spj,
   'evidence_tercatat',v_evidence,'tindak_lanjut_terbuka',v_pending,
   'catatan','Penutupan resmi tidak otomatis. Kewajiban SPJ dan bukti harus diperiksa sesuai aturan perjalanan nyata.');
END;
$fn$;
REVOKE ALL ON FUNCTION public.sentarum_travel_readiness(uuid,uuid)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sentarum_travel_readiness(uuid,uuid)
 TO authenticated;

INSERT INTO private.sentarum_manual_migrations(migration_id,description)
VALUES ('20261029001601_renstra_actual_and_closure_readiness_staging_v1',
 'Usulan realisasi Renstra dengan evidence, kontribusi kegiatan, ringkasan kelengkapan perjalanan tanpa penutupan otomatis');

DO $gate$
DECLARE v_bad int;v_steps int;v_store_policies int;v_asset_policies int;
BEGIN
 SELECT count(*) INTO v_bad FROM pg_catalog.pg_class c
 JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind IN ('r','p') AND NOT c.relrowsecurity;
 SELECT count(*) INTO v_steps FROM private.sentarum_manual_migrations;
 SELECT count(*) INTO v_store_policies FROM pg_catalog.pg_policies
 WHERE schemaname='storage' AND tablename='objects'
   AND policyname IN ('sentarum_015_evidence_admin_select','sentarum_015_evidence_admin_insert');
 SELECT count(*) INTO v_asset_policies FROM pg_catalog.pg_policies
 WHERE schemaname='public' AND tablename='document_assets'
  AND policyname='sentarum_015_document_asset_admin_read';
 IF v_bad<>0 OR v_steps<>14 OR v_store_policies<>2 OR v_asset_policies<>1 THEN
    RAISE EXCEPTION 'STOP: pemeriksaan akhir gagal (no_rls %, steps %, storage %, metadata %)',
      v_bad,v_steps,v_store_policies,v_asset_policies;
 END IF;
 IF has_table_privilege('anon','public.document_assets','SELECT') OR
    has_table_privilege('authenticated','public.document_assets','INSERT') OR
    has_table_privilege('authenticated','public.spj_cost_lines','UPDATE') THEN
    RAISE EXCEPTION 'STOP: izin tabel tidak boleh terbuka'; END IF;
END;
$gate$;
COMMIT;

SELECT 'SIAP_UJI_015_016' AS status,
  (SELECT count(*) FROM private.sentarum_manual_migrations) AS migrasi_tercatat,
  (SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','p') AND NOT c.relrowsecurity) AS tabel_tanpa_rls,
  (SELECT count(*) FROM pg_catalog.pg_policies WHERE schemaname='storage' AND tablename='objects'
    AND policyname LIKE 'sentarum_015_evidence_admin_%') AS kebijakan_storage_admin,
  (SELECT count(*) FROM pg_catalog.pg_policies WHERE schemaname='public' AND tablename='document_assets'
    AND policyname='sentarum_015_document_asset_admin_read') AS kebijakan_metadata,
  has_table_privilege('anon','public.document_assets','SELECT') AS anon_bisa_baca_metadata,
  has_table_privilege('authenticated','public.spj_cost_lines','UPDATE') AS login_bisa_ubah_spj_langsung;
