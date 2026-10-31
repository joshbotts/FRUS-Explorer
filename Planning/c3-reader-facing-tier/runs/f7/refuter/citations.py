import re,json,sqlite3
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
db=sqlite3.connect(f"file:{DB}?mode=ro",uri=True)
RUN="/Users/jbotts/frus-analysis/c3f/runs/f7/"
ov=open(RUN+"overview.md",encoding="utf-8").read()
man={v["volumeId"]:v for v in json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))}
print("manifest volume keys:",list(man["frus1950v06"].keys()))
# every printed "Document(s) N [and M]" immediately followed by URL(s)
pat=re.compile(r"\(([^()]*?Documents?\s+(\d+)(?:\s+and\s+(\d+))?)[^()]*?(https://history\.state\.gov/historicaldocuments/(frus[\w\-]+)/d(\w+)(?:\s+and\s+https://history\.state\.gov/historicaldocuments/(frus[\w\-]+)/d(\w+))?)\)")
seen=set()
for m in pat.finditer(ov):
    cite=m.group(1); nums=[m.group(2)]+([m.group(3)] if m.group(3) else [])
    urls=[(m.group(5),"d"+m.group(6))]+([(m.group(7),"d"+m.group(8))] if m.group(7) else [])
    for n,(v,d) in zip(nums,urls):
        r=db.execute("select document_number,substr(replace(header,char(10),' '),1,120) from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
        dn=r[0] if r else None
        ok = (dn is not None and str(dn).strip()==n) or (d=="d"+n)
        title=man[v]["title"] if v in man else "?"
        key=(v,d)
        print(f"{'OK ' if ok else 'BAD'} printed Document {n} -> {v}/{d} | document_number={dn} | manifest title: {title[:95]}")
        print(f"      cited as: {cite[:110]}")
print()
print("=== headers, dates, numbers of the 24 cited documents ===")
cited=[]
for m in re.finditer(r"historicaldocuments/(frus[\w\-]+)/(d\w+)",ov):
    p=(m.group(1),m.group(2))
    if p not in cited: cited.append(p)
for v,d in cited:
    r=db.execute("select document_number,substr(replace(header,char(10),' '),1,150),substr(dateline,1,80) from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    dt=db.execute("select date_iso from document_dates where volume_id=? and document_id=?",(v,d)).fetchone()
    print(f"  {v}/{d} #{r[0]} {dt[0][:10] if dt and dt[0] else '?'} | {r[1]} | {r[2]}")
print()
b=db.execute("select body_text,source_note from document_cache where volume_id='frus1950v06' and document_id='d32'").fetchone()
t=" ".join((b[1] or '').split()+b[0].split())
for kw in ["14-nation","fourteen","14 nation","14 countries"]:
    i=t.find(kw); print(f"d32 '{kw}':", t[max(0,i-80):i+80] if i>=0 else "NOT FOUND")
print()
print("RG 305 rows in document_sources:",db.execute("select count(*),count(distinct volume_id) from document_sources where record_group='305'").fetchone(), db.execute("select volume_id,document_id,substr(raw_text,1,140) from document_sources where record_group='305' limit 3").fetchall())
print("manifest volumes among the 79 with earliest year 1945:",[ (v,man[v]['dateRange']['earliest']) for v in man if v in set(l.strip() for l in open(RUN+'work/ea_vols_list.txt')) and man[v]['dateRange']['earliest'][:4]=='1945'])
print("'effectiveness of our information' whole index:",db.execute("select count(*) from frus_documents where frus_documents match '\"effectiveness of our information\"'").fetchone())
print("d105 in belief family?",db.execute("select count(*) from frus_documents f join document_cache d on d.rowid=f.rowid where frus_documents match ? and d.volume_id='frus1969-76v38p2' and d.document_id='d105'",['"oriental mind" OR "asian mind" OR "asian psychology" OR "psychology of asians" OR "oriental psychology" OR "asiatic mind"']).fetchone())
# d447: which plausible FTS predicates return it?
for q in ['"information agency" OR "information service" OR "information program" OR "psychological strategy" OR "psychological warfare" OR "voice of america" OR propaganda','usis','colonialism','"support colonialism"','malaya AND usia']:
    print(f"d447 matched by {q!r}:",bool(db.execute("select 1 from frus_documents f join document_cache d on d.rowid=f.rowid where frus_documents match ? and d.volume_id='frus1955-57v22' and d.document_id='d447'",[q]).fetchone()))
