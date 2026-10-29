from playwright.sync_api import sync_playwright
from pathlib import Path
import json, threading
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
D=Path(__file__).parent
ORG='11111111-1111-4111-8111-111111111111'; DOC='22222222-2222-4222-8222-222222222222'; TRIP='33333333-3333-4333-8333-333333333333';SPJ='44444444-4444-4444-8444-444444444444'; TAR='55555555-5555-4555-8555-555555555555';IND='66666666-6666-4666-8666-666666666666'; UNIT='77777777-7777-4777-8777-777777777777'
state={'docs':[], 'assets':[], 'events':[]}
class Quiet(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',18576),lambda *a,**kw:Quiet(*a,directory=str(D),**kw))
threading.Thread(target=server.serve_forever,daemon=True).start()
with sync_playwright() as p:
 browser=p.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox'])
 page=browser.new_page(viewport={'width':390,'height':844}); errors=[]
 page.on('pageerror',lambda e:errors.append(str(e)))
 def mock(route):
  req=route.request;url=req.url;state['events'].append((req.method,url.split('?')[0]));data=[]
  if 'organizations?' in url:data=[{'id':ORG,'code':'SETWAN_KAPUAS_HULU','name':'Sekretariat'}]
  elif 'org_units?' in url:data=[{'id':UNIT,'org_id':ORG,'code':'TUKEP','active':True}]
  elif 'business_records?' in url:data=[{'id':DOC,'module_key':'dokumen','display_title':'Dokumen lama','state':'active','unit_id':UNIT},{'id':'88888888-8888-4888-8888-888888888888','module_key':'agenda','display_title':'Agenda Uji','state':'active','unit_id':UNIT}]+state['docs']
  elif 'travel_registers?' in url:data=[{'id':TRIP,'purpose':'Koordinasi Uji','kind':'Rombongan','status':'Draf','org_id':ORG}]
  elif 'spj_packages?' in url:data=[{'id':SPJ,'travel_id':TRIP,'participant_id':'99999999-9999-4999-8999-999999999999','reference_number':'SPJ-01'}]
  elif 'renstra_annual_targets?' in url:data=[{'id':TAR,'indicator_id':IND,'year':2026,'target_numeric':83,'actual_numeric':None,'actual_status':'belum_dilaporkan'}]
  elif 'renstra_indicators?' in url:data=[{'id':IND,'code':'IKM','name':'Indeks Kepuasan Masyarakat','unit':'indeks'}]
  elif 'document_assets?' in url:data=state['assets']
  elif 'rpc/sentarum_save_generic' in url:
   x=req.post_data_json;state['docs'].append({'id':x['p_id'],'module_key':'dokumen','display_title':x['p_title'],'state':'active','unit_id':UNIT});data=[{'record_id':x['p_id'],'new_revision':1,'saved_state':'active'}]
  elif 'rpc/sentarum_attach_private_file' in url:
   x=req.post_data_json;state['assets'].append({'id':'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','record_id':x['p_document_record_id'],'filename':x['p_filename'],'classification':'restricted','storage_bucket':'sentarum-evidence-staging','storage_path':x['p_path'],'uploaded_at':'2026-10-29T01:00:00Z'});data='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  elif 'rpc/sentarum_renstra_propose_actual' in url:data={'state':'dalam_verifikasi'}
  elif 'rpc/sentarum_travel_readiness' in url:data={'pelaksanaan':'Draf','peserta_aktif':2,'spj_tercatat':2,'peserta_tanpa_spj':0,'spj_tanpa_rincian':0,'evidence_tercatat':1,'tindak_lanjut_terbuka':1,'catatan':'Perlu pemeriksaan manusia.'}
  elif 'rpc/' in url:data={'id':'cccccccc-cccc-4ccc-8ccc-cccccccccccc'}
  elif '/storage/v1/object/' in url:data={'Key':'okay'}
  route.fulfill(status=200,content_type='application/json',body=json.dumps(data))
 page.route('https://twwadofupxcupmjzdbgj.supabase.co/**',mock)
 page.set_content((D/'index.html').read_text(),wait_until='domcontentloaded',timeout=30000)
 page.click('#s15OpenBtn')
 assert page.locator('#s15Layer').evaluate('(e)=>e.hidden')
 assert not page.locator('#s12Layer').evaluate('(e)=>e.hidden')
 page.click('#s12Close')
 page.evaluate('window.__SENTARUM_STAGE12_AUTH__={token:()=>"fake.jwt.token"};Object.defineProperty(window,"crypto",{configurable:true,value:{randomUUID:()=>"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",subtle:{digest:async()=>new Uint8Array(32).buffer}}})')
 page.click('#s15OpenBtn');page.wait_for_timeout(300)
 assert 'Tersambung:' in page.locator('#s15Status').inner_text(),page.locator('#s15Status').inner_text()
 page.screenshot(path=str(D/'PRATINJAU_PONSEL.png'))
 page.fill('#s15Title','Laporan Uji');page.set_input_files('#s15File',{'name':'uji.pdf','mimeType':'application/pdf','buffer':b'%PDF-1.4\nTEST\n%%EOF'})
 page.click('#s15Upload');page.wait_for_timeout(400)
 assert len(state['assets'])==1,page.locator('#s15Status').inner_text()
 assert 'Berhasil:' in page.locator('#s15Status').inner_text()
 page.click('[data-s15tab="renstra"]');assert 'Indeks Kepuasan Masyarakat' in page.locator('#s15Targets').inner_text()
 page.select_option('#s15TargetPick',TAR);page.fill('#s15Actual','82.4');page.select_option('#s15EvidencePick',state['docs'][-1]['id'])
 page.click('#s15SubmitActual');page.wait_for_timeout(250)
 assert 'Usulan realisasi' in page.locator('#s15Status').inner_text(),page.locator('#s15Status').inner_text()
 page.click('[data-s15tab="readiness"]');page.select_option('#s15ReadinessTrip',TRIP);page.click('#s15Check');page.wait_for_timeout(250)
 assert 'Peserta tanpa SPJ: 0' in page.locator('#s15CheckResult').inner_text()
 page.click('[data-s15tab="release"]');assert 'NO-GO' in page.locator('#s15TabRelease').inner_text()
 page.set_viewport_size({'width':1280,'height':800});page.click('[data-s15tab="renstra"]');page.screenshot(path=str(D/'PRATINJAU_DESKTOP.png'))
 print('PASS',len(state['events']),'requests; assets',len(state['assets']),'JS_ERRORS',errors)
 assert not errors,errors
 browser.close()
