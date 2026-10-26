# refuter: every double-quoted passage in overview.md (pair = the next history.state.gov URL after it) and every excerpt in the
# collection, checked segment-strict against lower-cased [a-z0-9] of header||dateline||source_note||body_text of the exact pair.
import sqlite3, json, re
R='/Users/jbotts/frus-analysis/c3/runs/r9'
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
norm=lambda s: re.sub(r'[^a-z0-9]','',s.lower())
cache={}
def doc(v,d):
    if (v,d) not in cache:
        r=con.execute("SELECT header,dateline,source_note,body_text,document_number FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        cache[(v,d)]=None if r is None else (norm((r[0] or '')+(r[1] or '')+(r[2] or '')+(r[3] or '')), r[4])
    return cache[(v,d)]
def check(q,v,d):
    row=doc(v,d)
    if row is None: return False,'PAIR NOT IN INDEX'
    text=row[0]
    segs=[s for s in re.split(r'…|\.\.\.|\[\.\.\.\]',q) if norm(s)]
    pos=0; offs=[]
    for s in segs:
        i=text.find(norm(s),pos)
        if i<0: return False,f'segment not found: {s[:60]!r}'
        offs.append(i); pos=i+len(norm(s))
    return True,f'found at {offs}'
t=open(R+'/overview.md',encoding='utf-8').read()
urlrx=re.compile(r'https://history\.state\.gov/historicaldocuments/([^/\s)]+)/([A-Za-z0-9_\-]+)')
quotes=[(m.start(),m.end(),m.group(1)) for m in re.finditer(r'"([^"]+)"',t)]
print('double-quoted passages in overview.md:',len(quotes))
results=[]; bad=0
for i,(s,e,q) in enumerate(quotes,1):
    m=urlrx.search(t,e)
    v,d=m.group(1),m.group(2)
    # the printed citation: text of the parenthetical piece that holds this URL
    para_start=t.rfind('(',0,m.start()); piece=t[para_start+1:m.start()]
    piece=piece.split(';')[-1].strip()
    ok,why=check(q,v,d)
    bad+= (not ok)
    results.append((i,q,v,d,piece,ok,why))
    print(f'Q{i:02d} {"OK " if ok else "FAIL"} {v}/{d} | {piece[:70]} | {q[:80]!r} | {why}')
print('overview quotations failing:',bad)
# printed citation -> pair resolution: document_number in the index, and the volume's manifest title
man=json.load(open('/Applications/FRUS Explorer.app/Contents/Resources/manifest.json'))
title={m.get('volumeId') or m['filename'].replace('.xml',''): re.sub(r'\s+',' ',m['title']) for m in man}
print('\nPRINTED CITATION RESOLUTION (distinct pairs cited in the overview):')
seen=set()
for mm in urlrx.finditer(t):
    v,d=mm.group(1),mm.group(2)
    if (v,d) in seen: continue
    seen.add((v,d))
    para_start=t.rfind('(',0,mm.start()); piece=t[para_start+1:mm.start()].split(';')[-1].strip()
    row=doc(v,d); dn=row[1] if row else None
    pd=re.search(r'Document (\d+)',piece); pd=pd.group(1) if pd else None
    flag='' if (dn is None or pd is None or str(dn)==pd) else '  <-- DOCUMENT NUMBER MISMATCH'
    idnum=re.sub(r'\D','',d)
    flag2='' if pd==idnum or pd is None else '  <-- id/number differ'
    print(f'  {v}/{d}: printed "{piece[:75]}" | index document_number={dn!r} | manifest: {title.get(v,"?")[:90]}{flag}{flag2}')
print('distinct pairs cited:',len(seen))
# collection excerpts
c=json.load(open(R+'/collection.fruscollection'))
ex=[x for x in c['entries'] if x['kind']=='excerpt']
nb=0
print('\nCOLLECTION EXCERPTS:',len(ex))
for i,x in enumerate(ex,1):
    ok,why=check(x['text'],x['volumeId'],x['documentId']); nb+=(not ok)
    print(f'E{i:02d} {"OK " if ok else "FAIL"} {x["volumeId"]}/{x["documentId"]} | {x["text"][:70]!r} | {why}')
print('collection excerpts failing:',nb)
json.dump({'overview':[dict(zip(['n','quote','volume','document','printed','ok','why'],r)) for r in results]},open(R+'/refuter/quotes_checked.json','w'),ensure_ascii=False,indent=1)
