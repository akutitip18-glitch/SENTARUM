-- SENTARUM / STAGING 014 — Model B — SPJ Per Individu (uji Admin)
-- Setelah tahap 013 lulus. SQL Editor, satu kali Run. BUKAN deployment produksi.
-- Data sebelumnya TIDAK dihapus; semua perubahan dibuat dalam satu transaksi.
-- Operasi langsung pada tabel model B tidak diberikan kepada role klien.
BEGIN;
SET LOCAL statement_timeout = '120s';

DO $preflight$
DECLARE v_tables integer;v_rls integer;v_steps integer;v_audit integer;v_admin integer;
BEGIN
  SELECT count(*)::integer,count(*) FILTER(WHERE NOT c.relrowsecurity)::integer INTO v_tables,v_rls
  FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind IN ('r','p');
  SELECT count(*)::integer INTO v_audit FROM pg_catalog.pg_trigger t
  JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
  JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND NOT t.tgisinternal AND t.tgname LIKE 'trg_sentarum_audit_%';
  SELECT count(*)::integer INTO v_steps FROM private.sentarum_manual_migrations;
  SELECT count(*)::integer INTO v_admin FROM public.memberships m
  JOIN public.user_profiles p ON p.user_id=m.user_id
  JOIN auth.users a ON a.id=p.user_id
  JOIN public.organizations o ON o.id=m.org_id
  WHERE lower(btrim(a.email))='admin@sentarum.go.id'
    AND p.is_active AND m.active AND m.role_code='admin_aplikasi'
    AND o.code='SETWAN_KAPUAS_HULU'
    AND m.valid_from<=current_date AND (m.valid_until IS NULL OR m.valid_until>=current_date);
  IF v_tables<>28 OR v_rls<>0 OR v_audit<>28 OR v_steps<>11 OR v_admin<>1 THEN
    RAISE EXCEPTION 'STOP 014: tabel %, tanpa RLS %, audit %, migrasi %, Admin %; target 28,0,28,11,1',v_tables,v_rls,v_audit,v_steps,v_admin;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM private.sentarum_manual_migrations WHERE migration_id='20261029001301_generic_server_workspace_manual_v1') THEN
    RAISE EXCEPTION 'STOP 014: fondasi 013 belum dicatat'; END IF;
  IF EXISTS(SELECT 1 FROM private.sentarum_manual_migrations WHERE migration_id='20261029001401_model_b_individual_admin_rpc_staging_v1') THEN
    RAISE EXCEPTION 'STOP 014: sudah dipasang; jangan jalankan ulang'; END IF;
  IF EXISTS (SELECT 1 FROM public.spj_packages) OR EXISTS (SELECT 1 FROM public.spj_cost_lines) OR EXISTS (SELECT 1 FROM public.spj_participant_coverage) THEN
    RAISE EXCEPTION 'STOP 014: SPJ sudah berisi data; wajib audit/migrasi individual terlebih dahulu'; END IF;
  IF to_regprocedure('public.sentarum_modelb_command(text,uuid,jsonb)') IS NOT NULL THEN
    RAISE EXCEPTION 'STOP 014: fungsi Model B sudah ada'; END IF;
  IF NOT EXISTS(SELECT 1 FROM storage.buckets WHERE id='sentarum-evidence-staging' AND public=false) THEN
    RAISE EXCEPTION 'STOP 014: bucket evidence harus privat'; END IF;
  IF has_table_privilege('authenticated','public.spj_cost_lines','INSERT') OR
     has_table_privilege('anon','public.travel_registers','SELECT') THEN
    RAISE EXCEPTION 'STOP 014: izin model B sudah berubah; audit dulu'; END IF;
END;
$preflight$;

-- SPJ wajib 1 paket / peserta / perjalanan. Tidak mengubah data lama: preflight mensyaratkan SPJ staging kosong.
ALTER TABLE public.spj_packages ADD COLUMN participant_id uuid NOT NULL;
ALTER TABLE public.spj_packages ADD CONSTRAINT spj_014_individual_only CHECK (kind='Individual');
ALTER TABLE public.spj_packages ADD CONSTRAINT spj_014_owner_fk
 FOREIGN KEY(participant_id,org_id,travel_id) REFERENCES public.travel_participants(id,org_id,travel_id) ON DELETE RESTRICT;
CREATE UNIQUE INDEX spj_014_per_person_per_trip ON public.spj_packages(org_id,travel_id,participant_id);
ALTER TABLE public.spj_cost_lines ADD CONSTRAINT spj_014_cost_owner_required
 CHECK (scope='Individual' AND participant_id IS NOT NULL);

-- Validasi relasi lintas tabel: coverage dan biaya hanya untuk pemilik SPJ yang sama.
-- Trigger turut melindungi import/akses tinggi, tidak sekadar UI/RPC.
CREATE FUNCTION private.sentarum_014_guard_spj_owner()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $guard$
DECLARE v_owner uuid;
BEGIN
 SELECT p.participant_id INTO v_owner
 FROM public.spj_packages p
 WHERE p.id=NEW.spj_id AND p.org_id=NEW.org_id AND p.travel_id=NEW.travel_id;
 IF v_owner IS NULL OR NEW.participant_id IS DISTINCT FROM v_owner THEN
   RAISE EXCEPTION 'Peserta dalam rincian/tautan harus pemilik SPJ individual' USING ERRCODE='23514';
 END IF;
 IF TG_TABLE_NAME='spj_cost_lines' THEN
   IF NEW.scope <> 'Individual' THEN
     RAISE EXCEPTION 'Biaya SPJ harus individual' USING ERRCODE='23514';
   END IF;
 END IF;
 RETURN NEW;
END;
$guard$;
REVOKE ALL ON FUNCTION private.sentarum_014_guard_spj_owner() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER trg_sentarum_014_coverage_owner
 BEFORE INSERT OR UPDATE ON public.spj_participant_coverage
 FOR EACH ROW EXECUTE FUNCTION private.sentarum_014_guard_spj_owner();
CREATE TRIGGER trg_sentarum_014_cost_owner
 BEFORE INSERT OR UPDATE ON public.spj_cost_lines
 FOR EACH ROW EXECUTE FUNCTION private.sentarum_014_guard_spj_owner();

-- Baca Model B untuk Admin aktif dalam organisasi yang sama, tanpa membuka hak tulis tabel.
GRANT SELECT ON
 public.travel_registers, public.travel_participants, public.spj_packages,
 public.spj_participant_coverage, public.spj_cost_lines,
 public.travel_evidence_links, public.travel_followups TO authenticated;
DO $policies$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'travel_registers','travel_participants','spj_packages','spj_participant_coverage',
  'spj_cost_lines','travel_evidence_links','travel_followups'] LOOP
   EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (public.sentarum_is_org_admin(org_id))',
      'sentarum_014_admin_read_'||t,t);
 END LOOP;
END;
$policies$;
-- Typed record tetap hanya dapat dibaca Admin, tidak dapat ditulis langsung.
CREATE POLICY sentarum_014_admin_read_typed_records ON public.business_records
 FOR SELECT TO authenticated USING (public.sentarum_is_org_admin(org_id)
 AND module_key IN ('perjadin','peserta_perjadin','spj'));

-- Satu RPC untuk pencatatan Model B, dengan setiap operasi terjadi secara atomik.
-- Tidak memberikan kewenangan pengesahan SPJ, pembayaran, verifikasi evidence,
-- atau penutupan administratif. Pembaca umum tetap ditolak oleh RLS.
CREATE FUNCTION public.sentarum_modelb_command(p_command text,p_org_id uuid,p_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE
 v_uid uuid;v_id uuid;v_trip uuid;v_spj uuid;v_part uuid;v_doc uuid;v_unit uuid;
 v_agenda uuid;v_person uuid;v_dpa uuid;v_kind text;v_title text;v_purpose text;
 v_scope text;v_category text;v_description text;v_name text;v_reference text;
 v_status text;v_followup text;v_amount numeric;v_sdate date;v_edate date;
 v_due date;v_rev integer;v_row public.business_records%ROWTYPE;
BEGIN
 v_uid := auth.uid();
 IF v_uid IS NULL OR p_org_id IS NULL OR NOT public.sentarum_is_org_admin(p_org_id) THEN
    RAISE EXCEPTION 'Akses ditolak: Admin organisasi aktif diperlukan' USING ERRCODE='42501';
 END IF;
 IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR
    pg_catalog.octet_length(p_data::text)>32768 THEN
    RAISE EXCEPTION 'Payload harus object JSON maksimal 32 KB'; END IF;
 IF p_command NOT IN ('travel_create','travel_update','participant_add','spj_create',
      'cost_add','evidence_link','followup_add') THEN
    RAISE EXCEPTION 'Perintah Model B tidak tersedia'; END IF;

 IF p_command IN ('travel_create','travel_update') THEN
   v_agenda:=NULLIF(p_data->>'agenda_record_id','')::uuid;
   v_kind:=NULLIF(pg_catalog.btrim(p_data->>'kind'),'');
   v_purpose:=NULLIF(pg_catalog.btrim(p_data->>'purpose'),'');
   v_sdate:=NULLIF(p_data->>'planned_start','')::date;
   v_edate:=NULLIF(p_data->>'planned_end','')::date;
   IF v_kind IS NULL OR v_kind NOT IN ('Individual','Rombongan') OR v_purpose IS NULL OR
      pg_catalog.length(v_purpose)>500 OR v_sdate IS NULL OR v_edate IS NULL OR v_edate<v_sdate THEN
      RAISE EXCEPTION 'Jenis, tujuan, dan tanggal perjalanan wajib benar'; END IF;
   IF v_agenda IS NULL OR NOT EXISTS(SELECT 1 FROM public.business_records r
     WHERE r.id=v_agenda AND r.org_id=p_org_id AND r.module_key='agenda' AND r.state='active') THEN
      RAISE EXCEPTION 'Pilih agenda aktif dari Data Server terlebih dahulu'; END IF;
   v_title:=pg_catalog.left('Perjalanan · '||v_purpose,250);
   IF p_command='travel_create' THEN
     SELECT u.id INTO v_unit FROM public.org_units u WHERE u.org_id=p_org_id AND u.code='UMKEU' AND u.active LIMIT 1;
     IF v_unit IS NULL THEN RAISE EXCEPTION 'Unit UMKEU tidak aktif / tidak tersedia'; END IF;
     v_id:=pg_catalog.gen_random_uuid();
     INSERT INTO public.business_records(id,org_id,unit_id,module_key,display_title,payload,state,created_by,updated_by)
     VALUES(v_id,p_org_id,v_unit,'perjadin',v_title,
       pg_catalog.jsonb_build_object('agendaId',v_agenda,'pelaksanaTipe',v_kind,'tujuan',v_purpose,'mulai',v_sdate,'akhir',v_edate),
       'draft',v_uid,v_uid);
     INSERT INTO public.travel_registers(id,org_id,unit_id,agenda_record_id,kind,purpose,planned_start,planned_end,status,review_required)
     VALUES(v_id,p_org_id,v_unit,v_agenda,v_kind,v_purpose,v_sdate,v_edate,'Draf',false);
     RETURN pg_catalog.jsonb_build_object('id',v_id,'revision',1,'kind','travel');
   ELSE
     v_id:=NULLIF(p_data->>'id','')::uuid;
     IF v_id IS NULL THEN RAISE EXCEPTION 'ID perjalanan wajib'; END IF;
     SELECT * INTO v_row FROM public.business_records WHERE id=v_id AND org_id=p_org_id FOR UPDATE;
     IF NOT FOUND OR v_row.module_key<>'perjadin' OR v_row.state<>'draft' THEN
       RAISE EXCEPTION 'Perjalanan tidak ditemukan atau tidak lagi berstatus draf'; END IF;
     IF v_row.revision IS DISTINCT FROM NULLIF(p_data->>'expected_revision','')::integer THEN
       RAISE EXCEPTION 'Revisi telah berubah. Muat ulang sebelum menyimpan'; END IF;
     UPDATE public.business_records SET display_title=v_title,
       payload=payload||pg_catalog.jsonb_build_object('agendaId',v_agenda,'pelaksanaTipe',v_kind,'tujuan',v_purpose,'mulai',v_sdate,'akhir',v_edate),
       revision=revision+1,updated_by=v_uid,updated_at=now() WHERE id=v_id RETURNING revision INTO v_rev;
     UPDATE public.travel_registers SET agenda_record_id=v_agenda,kind=v_kind,purpose=v_purpose,
       planned_start=v_sdate,planned_end=v_edate WHERE id=v_id AND org_id=p_org_id;
     RETURN pg_catalog.jsonb_build_object('id',v_id,'revision',v_rev,'kind','travel');
   END IF;
 END IF;

 IF p_command='participant_add' THEN
   v_trip:=NULLIF(p_data->>'travel_id','')::uuid;
   v_person:=NULLIF(p_data->>'person_record_id','')::uuid;
   v_name:=NULLIF(pg_catalog.btrim(p_data->>'manual_name'),'');
   SELECT unit_id INTO v_unit FROM public.travel_registers WHERE id=v_trip AND org_id=p_org_id;
   IF v_unit IS NULL THEN RAISE EXCEPTION 'Perjalanan tidak ditemukan'; END IF;
   IF v_person IS NULL AND (v_name IS NULL OR pg_catalog.length(v_name)>200) THEN
     RAISE EXCEPTION 'Pilih master peserta atau isi nama peserta valid'; END IF;
   IF v_person IS NOT NULL THEN
     SELECT display_title INTO v_title FROM public.business_records WHERE id=v_person AND org_id=p_org_id
      AND module_key IN ('pegawai','anggota','tenaga_ahli') AND state='active';
     IF v_title IS NULL THEN RAISE EXCEPTION 'Master peserta tidak tersedia atau tidak aktif'; END IF;
   ELSE v_title:=v_name; END IF;
   v_id:=pg_catalog.gen_random_uuid();
   INSERT INTO public.business_records(id,org_id,unit_id,module_key,display_title,payload,state,created_by,updated_by)
   VALUES(v_id,p_org_id,v_unit,'peserta_perjadin',pg_catalog.left(v_title,250),
      pg_catalog.jsonb_build_object('perjadinId',v_trip,'namaPeserta',v_title,'anggotaId',v_person),
      'draft',v_uid,v_uid);
   INSERT INTO public.travel_participants(id,org_id,travel_id,person_record_id,legacy_manual_name,status)
   VALUES(v_id,p_org_id,v_trip,v_person,v_name,'Direncanakan');
   RETURN pg_catalog.jsonb_build_object('id',v_id,'kind','participant');
 END IF;

 IF p_command='spj_create' THEN
   v_trip:=NULLIF(p_data->>'travel_id','')::uuid;
   v_part:=NULLIF(p_data->>'participant_id','')::uuid;
   v_dpa:=NULLIF(p_data->>'dpa_record_id','')::uuid;
   v_reference:=NULLIF(pg_catalog.btrim(p_data->>'reference_number'),'');
   IF v_part IS NULL THEN RAISE EXCEPTION 'Pilih peserta untuk SPJ individual'; END IF;
   IF p_data ? 'kind' AND p_data->>'kind' <> 'Individual' THEN
     RAISE EXCEPTION 'SPJ di SENTARUM harus per individu'; END IF;
   IF v_reference IS NOT NULL AND pg_catalog.length(v_reference)>150 THEN
     RAISE EXCEPTION 'Nomor referensi maksimal 150 karakter'; END IF;
   SELECT t.unit_id INTO v_unit FROM public.travel_registers t
     JOIN public.travel_participants p ON p.travel_id=t.id AND p.org_id=t.org_id
     WHERE t.id=v_trip AND t.org_id=p_org_id AND p.id=v_part
       AND p.status<>'Dibatalkan';
   IF v_unit IS NULL THEN RAISE EXCEPTION 'Peserta bukan bagian dari perjalanan aktif atau telah dibatalkan'; END IF;
   IF EXISTS(SELECT 1 FROM public.spj_packages p
       WHERE p.org_id=p_org_id AND p.travel_id=v_trip AND p.participant_id=v_part) THEN
     RAISE EXCEPTION 'Peserta ini sudah memiliki SPJ pada perjalanan yang sama'; END IF;
   IF v_dpa IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.business_records r WHERE
       r.id=v_dpa AND r.org_id=p_org_id AND r.module_key='dpa' AND r.state='active') THEN
     RAISE EXCEPTION 'DPA tidak tersedia atau bukan record aktif'; END IF;
   v_id:=pg_catalog.gen_random_uuid();
   INSERT INTO public.business_records(id,org_id,unit_id,module_key,display_title,payload,state,created_by,updated_by)
   VALUES(v_id,p_org_id,v_unit,'spj',pg_catalog.left('SPJ Individual · '||COALESCE(v_reference,'belum bernomor'),250),
      pg_catalog.jsonb_build_object('perjadinId',v_trip,'pesertaId',v_part,'jenisSPJ','Individual','nomor',v_reference),
      'draft',v_uid,v_uid);
   INSERT INTO public.spj_packages(id,org_id,travel_id,participant_id,dpa_record_id,kind,status,reference_number,reconciliation_state)
   VALUES(v_id,p_org_id,v_trip,v_part,v_dpa,'Individual','Draf',v_reference,'perlu_rekonsiliasi');
   -- Cakupan otomatis satu peserta, tidak perlu langkah manual di formulir.
   INSERT INTO public.spj_participant_coverage(org_id,spj_id,travel_id,participant_id)
   VALUES(p_org_id,v_id,v_trip,v_part);
   RETURN pg_catalog.jsonb_build_object('id',v_id,'participant_id',v_part,'kind','individual_spj');
 END IF;

 IF p_command='cost_add' THEN
   v_spj:=NULLIF(p_data->>'spj_id','')::uuid;
   v_category:=NULLIF(pg_catalog.btrim(p_data->>'category'),'');
   v_description:=NULLIF(pg_catalog.btrim(p_data->>'description'),'');
   v_amount:=NULLIF(p_data->>'submitted_rp','')::numeric;
   SELECT travel_id,participant_id INTO v_trip,v_part
     FROM public.spj_packages WHERE id=v_spj AND org_id=p_org_id AND kind='Individual';
   IF v_trip IS NULL OR v_part IS NULL THEN RAISE EXCEPTION 'SPJ individual tidak ditemukan'; END IF;
   IF p_data ? 'scope' AND p_data->>'scope' <> 'Individual' THEN
     RAISE EXCEPTION 'Rincian biaya bersama tidak boleh dimasukkan ke SPJ individual'; END IF;
   IF p_data ? 'participant_id' AND NULLIF(p_data->>'participant_id','')::uuid IS DISTINCT FROM v_part THEN
     RAISE EXCEPTION 'Rincian biaya harus milik peserta pemilik SPJ'; END IF;
   IF v_category IS NULL OR pg_catalog.length(v_category)>120 OR v_description IS NULL OR
      pg_catalog.length(v_description)>500 OR v_amount IS NULL OR v_amount<0 OR
      v_amount<>pg_catalog.trunc(v_amount) OR v_amount>999999999999999999 THEN
      RAISE EXCEPTION 'Rincian biaya dan nominal harus valid'; END IF;
   INSERT INTO public.spj_cost_lines(org_id,spj_id,travel_id,scope,participant_id,category,description,submitted_rp)
   VALUES(p_org_id,v_spj,v_trip,'Individual',v_part,v_category,v_description,v_amount) RETURNING id INTO v_id;
   RETURN pg_catalog.jsonb_build_object('id',v_id,'participant_id',v_part,'kind','individual_cost');
 END IF;

 IF p_command='evidence_link' THEN
   v_trip:=NULLIF(p_data->>'travel_id','')::uuid;
   v_scope:=NULLIF(p_data->>'scope','');
   v_part:=NULLIF(p_data->>'participant_id','')::uuid;
   v_spj:=NULLIF(p_data->>'spj_id','')::uuid;
   v_doc:=NULLIF(p_data->>'document_record_id','')::uuid;
   v_category:=NULLIF(pg_catalog.btrim(p_data->>'evidence_kind'),'');
   IF v_category IS NULL OR pg_catalog.length(v_category)>150 THEN RAISE EXCEPTION 'Jenis bukti wajib'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.travel_registers WHERE id=v_trip AND org_id=p_org_id) THEN
       RAISE EXCEPTION 'Perjalanan tidak ditemukan'; END IF;
   IF v_doc IS NULL OR NOT EXISTS(SELECT 1 FROM public.business_records WHERE id=v_doc AND org_id=p_org_id
       AND module_key='dokumen' AND state='active') THEN
       RAISE EXCEPTION 'Dokumen yang sudah terdaftar diperlukan. Unggah file privat belum aktif'; END IF;
   IF (v_scope='Register' AND (v_part IS NOT NULL OR v_spj IS NOT NULL)) OR
      (v_scope='Peserta' AND (v_part IS NULL OR v_spj IS NOT NULL)) OR
      (v_scope='SPJ' AND (v_spj IS NULL OR v_part IS NOT NULL)) OR
      v_scope NOT IN ('Register','Peserta','SPJ') THEN
       RAISE EXCEPTION 'Cakupan bukti tidak sesuai'; END IF;
   INSERT INTO public.travel_evidence_links(org_id,travel_id,scope,participant_id,spj_id,
      document_record_id,evidence_kind,verification_state)
   VALUES(p_org_id,v_trip,v_scope,v_part,v_spj,v_doc,v_category,'Tercatat') RETURNING id INTO v_id;
   RETURN pg_catalog.jsonb_build_object('id',v_id,'kind','evidence');
 END IF;

 IF p_command='followup_add' THEN
   v_trip:=NULLIF(p_data->>'travel_id','')::uuid;
   v_followup:=NULLIF(pg_catalog.btrim(p_data->>'title'),'');
   v_name:=NULLIF(pg_catalog.btrim(p_data->>'assignee'),'');
   v_due:=NULLIF(p_data->>'due_on','')::date;
   IF v_followup IS NULL OR pg_catalog.length(v_followup)>500 THEN RAISE EXCEPTION 'Uraian tindak lanjut wajib'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.travel_registers WHERE id=v_trip AND org_id=p_org_id) THEN
     RAISE EXCEPTION 'Perjalanan tidak ditemukan'; END IF;
   INSERT INTO public.travel_followups(org_id,travel_id,title,assignee,due_on,state)
   VALUES(p_org_id,v_trip,v_followup,v_name,v_due,'Terbuka') RETURNING id INTO v_id;
   RETURN pg_catalog.jsonb_build_object('id',v_id,'kind','followup');
 END IF;

 RAISE EXCEPTION 'Perintah tidak diproses';
END;
$fn$;
REVOKE ALL ON FUNCTION public.sentarum_modelb_command(text,uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sentarum_modelb_command(text,uuid,jsonb) TO authenticated;

-- Transaksi uji memakai claims admin sementara, kemudian rollback data ujinya.
SAVEPOINT test_014;
SELECT pg_catalog.set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE lower(btrim(email))='admin@sentarum.go.id'),true);
SELECT pg_catalog.set_config('request.jwt.claims',
 (SELECT pg_catalog.json_build_object('sub',id::text,'role','authenticated')::text
 FROM auth.users WHERE lower(btrim(email))='admin@sentarum.go.id'),true);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE v_org uuid;v_unit uuid;v_agenda uuid;v_trip uuid;v_trip2 uuid;v_part uuid;v_other uuid;
 v_spj uuid;v_doc uuid;v_cost uuid;v_n integer;v_denied bool:=false;
BEGIN
 SELECT id INTO STRICT v_org FROM public.organizations WHERE code='SETWAN_KAPUAS_HULU';
 SELECT id INTO STRICT v_unit FROM public.org_units WHERE org_id=v_org AND code='UMKEU';
 SELECT record_id INTO v_agenda FROM public.sentarum_save_generic(NULL,v_org,v_unit,
    'agenda','SIMULASI 014 Agenda','{"judul":"SIMULASI 014 Agenda"}'::jsonb,'active',NULL,'[]'::jsonb);
 SELECT (public.sentarum_modelb_command('travel_create',v_org,
    jsonb_build_object('agenda_record_id',v_agenda,'kind','Rombongan','purpose','SIMULASI 014 Koordinasi',
    'planned_start','2026-11-01','planned_end','2026-11-02'))->>'id')::uuid INTO v_trip;
 SELECT (public.sentarum_modelb_command('travel_create',v_org,
    jsonb_build_object('agenda_record_id',v_agenda,'kind','Individual','purpose','SIMULASI 014 Lain',
    'planned_start','2026-11-01','planned_end','2026-11-02'))->>'id')::uuid INTO v_trip2;
 SELECT (public.sentarum_modelb_command('participant_add',v_org,
    jsonb_build_object('travel_id',v_trip,'manual_name','SIMULASI 014 A'))->>'id')::uuid INTO v_part;
 SELECT (public.sentarum_modelb_command('participant_add',v_org,
    jsonb_build_object('travel_id',v_trip2,'manual_name','SIMULASI 014 B'))->>'id')::uuid INTO v_other;
 SELECT (public.sentarum_modelb_command('spj_create',v_org,
    jsonb_build_object('travel_id',v_trip,'participant_id',v_part,'reference_number','SIM-014-A'))->>'id')::uuid INTO v_spj;
 IF NOT EXISTS(SELECT 1 FROM public.spj_participant_coverage WHERE spj_id=v_spj AND participant_id=v_part) THEN
   RAISE EXCEPTION 'UJI 014: cakupan individu tidak otomatis dibuat'; END IF;
 -- Peserta lain dari register berbeda ditolak.
 BEGIN
   PERFORM public.sentarum_modelb_command('spj_create',v_org,
     jsonb_build_object('travel_id',v_trip,'participant_id',v_other,'reference_number','SIM-LINTAS'));
 EXCEPTION WHEN OTHERS THEN v_denied:=true;
 END;
 IF NOT v_denied THEN RAISE EXCEPTION 'UJI 014: SPJ lintas perjalanan tidak ditolak'; END IF;
 -- Satu peserta tidak boleh punya dua SPJ dalam perjalanan yang sama.
 v_denied:=false;
 BEGIN
   PERFORM public.sentarum_modelb_command('spj_create',v_org,
     jsonb_build_object('travel_id',v_trip,'participant_id',v_part,'reference_number','SIM-DUPLIKAT'));
 EXCEPTION WHEN OTHERS THEN v_denied:=true;
 END;
 IF NOT v_denied THEN RAISE EXCEPTION 'UJI 014: SPJ individu duplikat tidak ditolak'; END IF;
 -- Biaya peserta lain atau biaya bersama tidak boleh dimasukkan.
 v_denied:=false;
 BEGIN
   PERFORM public.sentarum_modelb_command('cost_add',v_org,
     jsonb_build_object('spj_id',v_spj,'scope','Bersama','category','Transport','description','Tidak sah','submitted_rp','200000'));
 EXCEPTION WHEN OTHERS THEN v_denied:=true;
 END;
 IF NOT v_denied THEN RAISE EXCEPTION 'UJI 014: biaya bersama tidak ditolak'; END IF;
 v_denied:=false;
 BEGIN
   PERFORM public.sentarum_modelb_command('cost_add',v_org,
     jsonb_build_object('spj_id',v_spj,'participant_id',v_other,'category','Transport','description','Tidak sah','submitted_rp','200000'));
 EXCEPTION WHEN OTHERS THEN v_denied:=true;
 END;
 IF NOT v_denied THEN RAISE EXCEPTION 'UJI 014: biaya milik peserta lain tidak ditolak'; END IF;
 SELECT (public.sentarum_modelb_command('cost_add',v_org,
    jsonb_build_object('spj_id',v_spj,'category','Transport','description','SIMULASI 014 transport individu','submitted_rp','200000'))->>'id')::uuid INTO v_cost;
 PERFORM public.sentarum_modelb_command('cost_add',v_org,
    jsonb_build_object('spj_id',v_spj,'category','Harian','description','SIMULASI 014 harian individu','submitted_rp','100000'));
 IF (SELECT sum(submitted_rp) FROM public.spj_cost_lines WHERE spj_id=v_spj)<>300000 THEN
    RAISE EXCEPTION 'UJI 014: perhitungan SPJ individu tidak sesuai'; END IF;
 IF (SELECT count(*) FROM public.spj_cost_lines WHERE spj_id=v_spj AND (scope<>'Individual' OR participant_id<>v_part))<>0 THEN
    RAISE EXCEPTION 'UJI 014: pemilik rincian biaya tidak sesuai'; END IF;
 SELECT record_id INTO v_doc FROM public.sentarum_save_generic(NULL,v_org,v_unit,
   'dokumen','SIMULASI 014 Dokumen','{"judul":"SIMULASI 014 Dokumen"}'::jsonb,'active',NULL,'[]'::jsonb);
 PERFORM public.sentarum_modelb_command('evidence_link',v_org,
   jsonb_build_object('travel_id',v_trip,'scope','Register','document_record_id',v_doc,'evidence_kind','Laporan'));
 PERFORM public.sentarum_modelb_command('followup_add',v_org,
   jsonb_build_object('travel_id',v_trip,'title','SIMULASI 014 Tindak Lanjut'));
 SELECT count(*) INTO v_n FROM public.travel_registers WHERE id IN (v_trip,v_trip2);
 IF v_n<>2 THEN RAISE EXCEPTION 'UJI 014: perjalanan tidak tersimpan'; END IF;
 v_denied:=false;
 PERFORM pg_catalog.set_config('request.jwt.claim.sub',pg_catalog.gen_random_uuid()::text,true);
 PERFORM pg_catalog.set_config('request.jwt.claims',jsonb_build_object('sub',pg_catalog.gen_random_uuid()::text,'role','authenticated')::text,true);
 BEGIN
  PERFORM public.sentarum_modelb_command('travel_create',v_org,
   jsonb_build_object('agenda_record_id',v_agenda,'kind','Individual','purpose','TIDAK SAH',
    'planned_start','2026-11-01','planned_end','2026-11-02'));
 EXCEPTION WHEN insufficient_privilege THEN v_denied:=true;
 END;
 IF NOT v_denied THEN RAISE EXCEPTION 'UJI 014: akun selain Admin dapat menulis'; END IF;
END;
$test$;
RESET ROLE;
ROLLBACK TO SAVEPOINT test_014;

DO $gate$
DECLARE v_rls int;v_audit int;v_policy int;
BEGIN
 SELECT count(*) FILTER(WHERE NOT c.relrowsecurity)::integer INTO v_rls
 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind IN ('r','p');
 SELECT count(*)::integer INTO v_audit FROM pg_catalog.pg_trigger t
 JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
 JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND NOT t.tgisinternal AND t.tgname LIKE 'trg_sentarum_audit_%';
 SELECT count(*)::integer INTO v_policy FROM pg_catalog.pg_policies WHERE
 schemaname='public' AND policyname LIKE 'sentarum_014_admin_read_%';
 IF v_rls<>0 OR v_audit<>28 OR v_policy<>8 THEN
   RAISE EXCEPTION 'STOP 014: RLS %, audit %, policies %',v_rls,v_audit,v_policy; END IF;
 IF has_table_privilege('anon','public.spj_packages','SELECT') OR
   has_table_privilege('authenticated','public.spj_cost_lines','INSERT') OR
   has_table_privilege('authenticated','public.travel_registers','UPDATE') THEN
   RAISE EXCEPTION 'STOP 014: izin tabel tidak sesuai'; END IF;
END;
$gate$;

INSERT INTO private.sentarum_manual_migrations(migration_id,description)
VALUES('20261029001401_model_b_individual_admin_rpc_staging_v1',
  'Model B staging: baca admin dengan RLS; RPC atomik pencatatan perjalanan, peserta, SPJ individual per peserta, evidence, tindak lanjut; UAT rollback');
COMMIT;

SELECT 'LULUS_014_SPJ_INDIVIDUAL' AS status,
 (SELECT count(*) FROM private.sentarum_manual_migrations) AS migrasi_tercatat,
 (SELECT count(*) FROM pg_catalog.pg_policies WHERE schemaname='public' AND policyname LIKE 'sentarum_014_admin_read_%') AS kebijakan_baca_model_b,
 (SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind IN('r','p') AND NOT c.relrowsecurity) AS tabel_tanpa_rls,
 has_table_privilege('anon','public.travel_registers','SELECT') AS anonim_bisa_baca_perjalanan,
 has_table_privilege('authenticated','public.spj_cost_lines','INSERT') AS login_bisa_tulis_biaya_langsung,
 (SELECT count(*) FROM public.travel_registers) AS perjalanan_tersimpan,
 (SELECT count(*) FROM public.spj_packages) AS spj_tersimpan,
 (SELECT count(*) FROM pg_catalog.pg_constraint WHERE conname IN ('spj_014_individual_only','spj_014_owner_fk','spj_014_cost_owner_required')) AS aturan_spj_individual;
