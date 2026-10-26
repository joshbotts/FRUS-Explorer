import json, re, sqlite3
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RUN="/Users/jbotts/frus-analysis/c3/runs/r3"
con=sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
ov=open(f"{RUN}/overview.md",encoding='utf-8').read()
urls=re.findall(r'https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/([A-Za-z0-9_\-]+)', ov)
seen=[]; 
for u in urls:
    if u not in seen: seen.append(u)
print("distinct URL-cited pairs in overview:", len(seen), "(total URL mentions:", len(urls),")")
man=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
vols = man if isinstance(man,list) else man.get('volumes', man)
titles={}
if isinstance(vols,list):
    for v in vols:
        vid=v.get('id') or v.get('volumeId') or v.get('volume_id')
        titles[vid]=v.get('title') or v.get('name')
elif isinstance(vols,dict):
    for vid,v in vols.items(): titles[vid]=v.get('title') if isinstance(v,dict) else v
c=json.load(open(f"{RUN}/collection.fruscollection"))
cpairs={(e['volumeId'],e['documentId']) for e in c['entries'] if e.get('kind')=='document'}
for v,d in seen:
    r=con.execute("SELECT c.header, c.dateline, c.document_number, dd.date_iso, c.is_front_matter, c.is_editorial_note FROM document_cache c LEFT JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?",(v,d)).fetchone()
    inc = (v,d) in cpairs
    print(f"\n{v}/{d}  in_collection={inc}")
    print("  volume title:", titles.get(v))
    if r:
        print("  header:", r[0].replace('\n',' ')[:120]); print("  dateline:", (r[1] or '').replace('\n',' ')[:100]); print("  docnum:", r[2], " date_iso:", r[3], " fm/edn:", r[4], r[5])
    else: print("  NO ROW")
