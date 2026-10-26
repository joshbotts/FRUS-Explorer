import sqlite3, json, re, collections
R8="/Users/jbotts/frus-analysis/c3/runs/r8/"
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
# distinct chapters actually used (label column of core_scope.tsv), and per-volume slot counts incl. editorial notes
labels=collections.Counter(); pv=collections.Counter(); pv_na=collections.Counter(); ed_by_vol=collections.Counter()
for l in open(R8+"core_scope.tsv"):
    f=l.rstrip("\n").split("\t")
    labels[f[5]]+=1; pv[f[0]]+=1
    if f[3]=="0": pv_na[f[0]]+=1
    else: ed_by_vol[f[0]]+=1
ch_labels=[k for k in labels if " | " not in k]; rg_labels=[k for k in labels if " | " in k]
print("distinct chapter paths in core_scope.tsv:",len(ch_labels),"| distinct range labels (range|chapter):",len(rg_labels),"| distinct ranges:",len({k.split(' | ')[0] for k in rg_labels}))
print("frus1913/14/15 slots:",{v:(pv[v],pv_na[v]) for v in ("frus1913","frus1914","frus1915")},"editorial notes by volume:",dict(ed_by_vol))
print("memo's per-volume list vs non-apparatus:",[(v,pv[v],pv_na[v]) for v in ("frus1914","frus1913","frus1915","frus1933v05","frus1944v07","frus1932v05","frus1931v02","frus1911","frus1930v03","frus1937v05","frus1945v09","frus1950v02")])
# Ed2 exclusion claim
print("Ed2 volumes in index:",db.execute("SELECT volume_id, COUNT(*), SUM(is_front_matter=0 AND is_editorial_note=0) FROM document_cache WHERE volume_id LIKE '%Ed2' GROUP BY 1").fetchall())
print("non-apparatus corpus incl Ed2:",db.execute("SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0").fetchone()[0],
      "| excl Ed2:",db.execute("SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT LIKE '%Ed2'").fetchone()[0])
for q in ['"department of state"','recognition','"international obligations"','"de facto"']:
    a=db.execute("SELECT COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0",(q,)).fetchone()
    b=db.execute("SELECT COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT LIKE '%Ed2'",(q,)).fetchone()
    print(f"corpus-wide {q}: incl Ed2 {a} | excl Ed2 {b}")
print("volume with no non-apparatus 'department of state' hit:",db.execute("""SELECT volume_id FROM document_cache GROUP BY volume_id HAVING volume_id NOT IN (SELECT d.volume_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '"department of state"' AND d.is_front_matter=0 AND d.is_editorial_note=0)""").fetchall())
# document_number for every cited pair (printed citation -> id)
ov=open(R8+"overview.md").read()
urls=sorted(set(re.findall(r"https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/([a-z_]*d\d+)",ov)))
coll=json.load(open(R8+"collection.fruscollection")); docs={(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"}
print("\ncited pairs:",len(urls))
for v,d in urls:
    r=db.execute("SELECT document_number, (SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?), is_editorial_note, is_front_matter FROM document_cache WHERE volume_id=? AND document_id=?",(v,d,v,d)).fetchone()
    print(f"  {v}/{d} number={r[0]!r} date={r[1]} ed={r[2]} fm={r[3]} in_collection={(v,d) in docs}")
print("cited pairs not in collection:",[p for p in urls if p not in docs])
# reading log lengths
bad=[]
for l in open(R8+"reading_log.tsv"):
    v,d,cap,ln,path=l.rstrip("\n").split("\t")
    real=db.execute("SELECT length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    if int(ln)!=real or int(cap)!=real: bad.append((v,d,cap,ln,real))
print("reading_log rows:",sum(1 for _ in open(R8+"reading_log.tsv")),"length mismatches:",bad)
# memo Q-table dates vs document_dates
memo=open(R8+"memo.md").read()
for m in re.finditer(r"\| (Q\d+) \| (frus[^,]+), ([a-z_]*d\d+) \| (\d{4}-\d{2}-\d{2}) \|",memo):
    dt=db.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?",(m.group(2),m.group(3))).fetchone()
    if not dt or dt[0]!=m.group(4): print("memo Q-table date mismatch:",m.groups(),"index:",dt)
print("Q-table dates checked")
# numerical file NAID and the manual's source
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cfi=json.load(open(R+"central-files-index.json")); nf=cfi["numericalFile"]
print("numericalFile keys:",list(nf.keys()))
print({k:v for k,v in nf.items() if k!="rolls"})
print("654171 appears in central-files-index.json:", "654171" in open(R+"central-files-index.json").read())
dcl=json.load(open(R+"decimal-class-labels.json"))
for s in dcl["schedules"]:
    if s["id"]=="1910-1949": print("schedule 1910-1949 source:",s.get("source"),"| sources:",str(s.get("sources"))[:400]); print(" subjects .00/.01:",{k:s["subjects"].get(k) for k in ("00","01") if isinstance(s.get("subjects"),dict)}, str(s.get("subjects"))[:300])
    if s["id"]=="1910-1949" and isinstance(s.get("relationsClasses"),dict): print(" relationsClasses 710.11 / 7:",{k:str(v)[:100] for k,v in s["relationsClasses"].items() if k in ("7","710","710.11","11")})
# the 1950s country-chapter hits the memo names
print("\nchapters_post1950_AR.tsv head:"); print("".join(open(R8+"chapters_post1950_AR.tsv").readlines()[:12]))
