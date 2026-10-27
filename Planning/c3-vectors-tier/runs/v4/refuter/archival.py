# Refuter: every archival identifier in the bottom line's second paragraph, against the bundled artifacts.
import json, re, sqlite3
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+'central-files-index.json'))
sf=json.load(open(R+'series-facts-index.json'))
pl=json.load(open(R+'presidential-library-catalog.json'))
ca=json.load(open(R+'collection-authority.json'))
vs=json.load(open(R+'volume-sources-index.json'))
ec=json.load(open(R+'external-citation-index.json'))
print("collection-authority keys:", {k:(type(v).__name__, len(v) if hasattr(v,'__len__') else v) for k,v in ca.items()})
print("volume-sources-index keys:", {k:(type(v).__name__, len(v) if hasattr(v,'__len__') else v) for k,v in vs.items()})
print("external-citation-index keys:", {k:(type(v).__name__, len(v) if hasattr(v,'__len__') else v) for k,v in ec.items()})
print("series-facts legend keys:", json.dumps(sf['legend'])[:1200])
def facts(na):
    r=sf['byNaId'].get(str(na))
    if not r: return None
    out={}
    for k,v in r.items():
        L=sf['legend']['keys'].get(k,{})
        if 'into' in L:
            arr=sf[L['into']]; out[L['field']]=[arr[i] for i in v] if isinstance(v,list) else arr[v]
        else: out[L.get('field',k)]=v
    return out
lots={r['lotNumber']:r for r in cf['lotFiles']}
print("\n== Lot files named in the bottom line (lot -> entry, NAID, title, dates, access) ==")
claims=[('65D438','A1 3053','27022950','Records Relating to the Cuban Missile Crisis','1962','1963','Restricted - Partly'),
        ('74D272','A1 5175','614703','Records of Under Secretary','1961','1966','Unrestricted'),
        ('66D501','UD-UP 293-B','648748','Files Pertaining to Operation Mongoose','1963','1965','Unrestricted'),
        ('62D418','A1 3147','2068466','Subject Files','1959','1962','Restricted - Partly'),
        ('62D24','A1 3148','2363836','Subject Files','1958','1961','Restricted - Partly'),
        ('62D1','A1 1583E/F','2838992','Records Relating to Activities with the National Security Council','1948','1961','Restricted - Partly'),
        ('66D95','A1 1586E','2839192','Records Relating to National Security Council Policy Papers','1947','1979','Restricted - Partly'),
        ('66D204','A1 1590','2538452','Presidential and Secretary of State Correspondence with Foreign Heads of State','1953','1964',None),
        ('64D199','A1 1566','602231',"Memorandums of Conversation",'1953','1964','Unrestricted'),
        ('65D330','A1 1566','602231',"Memorandums of Conversation",'1953','1964','Unrestricted'),
        ('73D191','A1-5758','1040618','Records Relating to Cuba','1957','1975','Restricted - Partly')]
for lot,entry,naid,title,y0,y1,acc in claims:
    r=lots.get(lot)
    if not r: print(lot,"NOT IN lotFiles"); continue
    f=facts(r.get('naId')) or {}
    ok_entry = entry in (r.get('hmsMlrEntryNumbers') or [])
    ok_naid = str(r.get('naId'))==naid
    ok_title = title.lower() in (r.get('title') or '').lower() or title.lower() in str(f.get('title','')).lower()
    ok_dates = str(f.get('inclusiveStartYear'))==y0 and str(f.get('inclusiveEndYear'))==y1
    ok_acc = (acc is None) or (f.get('accessStatus')==acc)
    print("%s | RG %s | entries %s | NAID %s | %s | %s-%s | access %s | creator %s"%(lot, r.get('recordGroup'), r.get('hmsMlrEntryNumbers'), r.get('naId'), r.get('title'), f.get('inclusiveStartYear'), f.get('inclusiveEndYear'), f.get('accessStatus'), f.get('creator')))
    print("    claim: entry %s naid %s title %s dates %s access %s"%(ok_entry, ok_naid, ok_title, ok_dates, ok_acc))
print("\n== 62D1 raw record ==", json.dumps(lots.get('62D1'))[:600])
print("\n== Presidential libraries ==")
for lib in pl['libraries']:
    if lib['citedAs'] in ('Kennedy Library','Johnson Library','Eisenhower Library','Carter Library'):
        for col in lib['collections']:
            t=col['title']
            if re.search(r'national security|whitman|papers as president|brzezinski|nsc|national security affairs', t, re.I):
                print(lib['citedAs'],'|',col['identifier'],'| NAID',col['naId'],'|',t,'| series:', [(s['title'],s['inclusiveDates'],s['naId']) for s in col.get('series',[]) if re.search(r'country|latin america|cuba|whitman', s['title'], re.I)][:4])
print("\n-- all Carter Library collections (titles):")
for lib in pl['libraries']:
    if lib['citedAs']=='Carter Library':
        for col in lib['collections']: print("   ", col['identifier'], col['naId'], col['title'])
print("\n== Nineteenth-century microfilm file units ==")
for s in cf['countrySeries']:
    for r in s['rolls']:
        fu=r.get('fileUnitTitle') or ''
        if r.get('fileUnitNaId') in (196006797,183303950,177380758) or str(r.get('fileUnitNaId')) in ('196006797','183303950','177380758'):
            print(s['displayName'],'|',fu,'| fileUnitNaId',r['fileUnitNaId'],'| series NAID', r.get('seriesNaId'), '| rg', r.get('recordGroup'), '| keys', sorted(r.keys())[:14]); break
print("\n== Central Decimal File: any identifier in the bundled data? ==")
hits=[]
for k,v in sf['byNaId'].items():
    f=facts(k)
    t=str(f.get('title',''))
    if re.search(r'decimal', t, re.I): hits.append((k,t,f.get('inclusiveStartYear'),f.get('inclusiveEndYear')))
print("series-facts titles with 'decimal':", hits[:20])
def scan(obj, pat, path='', out=None, depth=0):
    if out is None: out=[]
    if depth>6: return out
    if isinstance(obj, dict):
        for k,v in obj.items(): scan(v, pat, path+'/'+str(k), out, depth+1)
    elif isinstance(obj, list):
        for i,v in enumerate(obj[:5000]): scan(v, pat, path+'[%d]'%i, out, depth+1)
    elif isinstance(obj, str):
        if re.search(pat, obj, re.I): out.append((path, obj[:120]))
    return out
for name,obj in (('collection-authority',ca),('central-files-index',cf),('volume-sources-index',vs),('external-citation-index',ec)):
    h=scan(obj, r'central decimal file|decimal file')
    print(name, "strings mentioning 'decimal file':", len(h), h[:6])
print("numericalFile seriesNaId:", cf['numericalFile'].get('seriesNaId'), "| microfilm:", str(cf['numericalFile'].get('microfilm'))[:200])
print("central-files-index top keys:", list(cf.keys()))
for k in cf:
    if k not in ('lotFiles','countrySeries','numericalFile'): print("  ",k,":",json.dumps(cf[k])[:300])
# decimal-class glosses used in the overview (political affairs, finances, agriculture, commerce US-Cuba)
d=json.load(open(R+'decimal-class-labels.json'))
s=[x for x in d['schedules'] if x['id']=='1910-1949'][0]
print("\n== 1910-1949 schedule glosses ==")
print("class 8:", s['classes'].get('8'), "| country 37:", s['countries'].get('37'))
sub8=s['subjects'].get('8') if isinstance(s['subjects'].get('8'),dict) else None
print("subjects['8'] type:", type(s['subjects'].get('8')).__name__)
if sub8: print("  8/00:", sub8.get('00'), "| 8/51:", sub8.get('51'), "| 8/61:", sub8.get('61'), "| 8/61.3:", sub8.get('61.3'), "| 8/15:", sub8.get('15'))
print("class 6:", s['classes'].get('6'), "| country 11:", s['countries'].get('11'), "| 611.37 second country 37:", s['countries'].get('37'))
s2=[x for x in d['schedules'] if x['id']=='1950-1959'][0]; print("1950-59 class 7:", s2['classes'].get('7'), "country 37:", s2['countries'].get('37'))
