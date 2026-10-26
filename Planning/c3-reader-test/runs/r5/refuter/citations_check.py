import json, re, sqlite3
R='/Users/jbotts/frus-analysis/c3/runs/r5/'
c=sqlite3.connect('file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro',uri=True)
man={m['volumeId']:m for m in json.load(open('/Applications/FRUS Explorer.app/Contents/Resources/manifest.json'))}
ov=open(R+'overview.md',encoding='utf-8').read()
cits=re.findall(r'((?:Papers Relating to the )?Foreign Relations of the United States[^()]*?), Document (\d+), https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)',ov)
print('edition citations parsed:',len(cits))
bad=0; titles={}
for title,num,v,d in cits:
    titles.setdefault(v,set()).add(title)
    dn=c.execute("select document_number from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    if dn is None or str(dn[0])!=num: print('  DOCNUM MISMATCH',v,d,dn,num); bad+=1
print('document-number mismatches:',bad)
def norm(s): return re.sub(r'\s+',' ',s.replace('\n',' ')).strip()
for v,ts in sorted(titles.items()):
    mt=norm(man[v]['title']); 
    for t in ts:
        same = norm(t)==mt
        print(('OK   ' if same else 'DIFF ')+v+' | overview: '+t+' | manifest: '+mt)
