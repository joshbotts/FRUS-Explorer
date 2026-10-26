import sqlite3, json, re, ast, collections
R8="/Users/jbotts/frus-analysis/c3/runs/r8/"
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
src=open(R8+"core_build.py").read()
ch_txt=src[src.index("CH=[")+3:src.index("]\n# post-1950")+1]
CH=ast.literal_eval(ch_txt)
rg_txt=src[src.index("RANGES=[")+7:src.index("]\npaths={}")+1]
RANGES=ast.literal_eval(rg_txt)
print("CH entries:",len(CH),"RANGES:",len(RANGES))
# --- rebuild core from volume_structures (my own walk) ---
paths={}; chap_docs=collections.defaultdict(list)
def walk(vid,sec,path):
    t=" ".join((sec.get("title") or "").split()); p=path+[t] if t else path
    full=" > ".join(p)
    for d in sec.get("documentIds",[]): paths[(vid,d)]=full; chap_docs[(vid,full)].append(d)
    for s in sec.get("subsections",[]): walk(vid,s,p)
vols=sorted(set(v for v,_ in CH)|set(r[0] for r in RANGES))
for vid,sj in db.execute("SELECT volume_id, structure_json FROM volume_structures WHERE volume_id IN (%s)"%",".join("'%s'"%v for v in vols)):
    for s in json.loads(sj).get("sections",[]): walk(vid,s,[])
core={}; nf=[]; multi=[]
for v,sub in CH:
    hits=[(k,ds) for k,ds in chap_docs.items() if k[0]==v and sub in k[1]]
    if not hits: nf.append((v,sub))
    if len(hits)>1: multi.append((v,sub,len(hits)))
    for (vv,full),ds in hits:
        for d in ds: core.setdefault((vv,d),full)
n_ch_only=len(core)
for v,pre,lo,hi,label in RANGES:
    for (vv,d),full in paths.items():
        if vv==v and d.startswith(pre) and d[len(pre):].isdigit() and lo<=int(d[len(pre):])<=hi: core.setdefault((vv,d),label)
print("selectors not found:",nf); print("selectors matching >1 chapter:",multi)
print("core slots:",len(core),"(chapters only:",n_ch_only,")")
db.execute("CREATE TEMP TABLE core(volume_id TEXT, document_id TEXT, PRIMARY KEY(volume_id,document_id))")
db.executemany("INSERT INTO core VALUES(?,?)",list(core.keys()))
r=db.execute("""SELECT COUNT(*), SUM(d.is_front_matter), SUM(d.is_editorial_note), COUNT(DISTINCT CASE WHEN d.is_front_matter=0 AND d.is_editorial_note=0 THEN d.volume_id END),
 SUM(CASE WHEN d.is_front_matter=0 AND d.is_editorial_note=0 THEN 1 ELSE 0 END) FROM core c JOIN document_cache d ON d.volume_id=c.volume_id AND d.document_id=c.document_id""").fetchone()
print("M3 in document_cache:",r[0],"front_matter",r[1],"editorial",r[2],"| non-apparatus",r[4],"in",r[3],"volumes")
missing=db.execute("SELECT COUNT(*) FROM core c LEFT JOIN document_cache d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE d.volume_id IS NULL").fetchone()[0]
print("core slots not in document_cache:",missing)
# compare with the session's core_scope.tsv
sess=set(); sess_na=set()
for l in open(R8+"core_scope.tsv"):
    f=l.rstrip("\n").split("\t"); sess.add((f[0],f[1]))
    if f[3]=="0": sess_na.add((f[0],f[1]))
print("session core_scope.tsv rows:",len(sess),"non-apparatus:",len(sess_na),"| set equality with my rebuild:",sess==set(core.keys()))
# dates
r=db.execute("""SELECT MIN(dd.date_iso), MAX(dd.date_iso), SUM(dd.date_iso IS NULL) FROM core c JOIN document_cache d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
 LEFT JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0""").fetchone()
print("M3 date span:",r)
# volumes list with counts
pv=db.execute("""SELECT c.volume_id, COUNT(*) FROM core c JOIN document_cache d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY 1 ORDER BY 2 DESC""").fetchall()
print("per-volume:",pv)
# M4 decades
dec=db.execute("""SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM core c JOIN document_cache d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
 JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY 1 ORDER BY 1""").fetchall()
print("M4 core by decade:",dec)
la=[l.split("\t")[0] for l in open(R8+"la_volumes.tsv")]
print("la_volumes.tsv rows:",len(la),"Ed2 among them:",[v for v in la if v.endswith("Ed2")])
la2=[v for v in la if v not in ("frus1951-54IranEd2","frus1969-76ve15p2Ed2")]
inlist=",".join("'%s'"%v for v in la2)
basela=db.execute("""SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
 WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso IS NOT NULL AND d.volume_id IN (%s) GROUP BY 1"""%inlist).fetchall()
bl=dict(basela)
for k,n in dec:
    if k in bl: print(f"  {k}: {n} / {bl[k]} = {1000*n/bl[k]:.1f} per 1,000")
mex=db.execute("""SELECT COUNT(*) FROM core c JOIN document_cache d ON d.volume_id=c.volume_id AND d.document_id=c.document_id JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id
 WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso LIKE '191%' AND c.volume_id IN ('frus1913','frus1914','frus1915')""").fetchone()[0]
print("1910s core docs in frus1913/1914/1915:",mex)
mexch=db.execute("""SELECT COUNT(*) FROM core c JOIN document_cache d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND c.volume_id IN ('frus1913','frus1914','frus1915')""").fetchone()[0]
print("core docs in frus1913/1914/1915 (all dates):",mexch)
# M1 wider net
Q='NEAR(recogn* government, 6) OR NEAR(recogn* regime, 6) OR NEAR(recogn* junta, 6)'
r=db.execute("""SELECT COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (%s)"""%inlist,(Q,)).fetchone()
print("M1 wider net:",r,"over",len(la2),"volumes")
# M12 / M5 / M6 / M7 / control in core
def core_hits(q):
    return db.execute("""SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN core c ON c.volume_id=d.volume_id AND c.document_id=d.document_id WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0""",(q,)).fetchone()[0]
def corpus_hits(q):
    return db.execute("""SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0""",(q,)).fetchone()[0]
tot=db.execute("SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0").fetchone()[0]
print("non-apparatus corpus:",tot)
for name,q in [("recognition","recognition"),("international obligations",'"international obligations"'),("de facto",'"de facto"'),("free elections",'"free elections" OR "free election"'),("control dept of state",'"department of state"'),("control impossible","ZZZ_IMPOSSIBLE_ZZZ")]:
    c=core_hits(q); print(f"  core {name}: {c} of 3541 -> 1 in {3541/c:.1f}" if c else f"  core {name}: 0", end="")
    if name in ("recognition","international obligations","de facto","control dept of state"):
        w=corpus_hits(q); print(f" | corpus {w} of {tot} -> {w/tot:.3f}")
    else: print()
# M14 pointed-at
r=db.execute("SELECT COUNT(*), COUNT(DISTINCT e.volume_id||'/'||e.document_id) FROM external_citations e JOIN core c ON c.volume_id=e.volume_id AND c.document_id=e.document_id").fetchone()
print("M14 external_citations over core (all core slots):",r)
r=db.execute("""SELECT COUNT(*), COUNT(DISTINCT e.volume_id||'/'||e.document_id) FROM external_citations e JOIN core c ON c.volume_id=e.volume_id AND c.document_id=e.document_id JOIN document_cache d ON d.volume_id=e.volume_id AND d.document_id=e.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0""").fetchone()
print("M14 external_citations over core (non-apparatus only):",r)
print("M14 by repo/collection:",db.execute("""SELECT COALESCE(e.repository,'?'), COALESCE(e.collection,'?'), COUNT(*), COUNT(DISTINCT e.volume_id||'/'||e.document_id) FROM external_citations e JOIN core c ON c.volume_id=e.volume_id AND c.document_id=e.document_id GROUP BY 1,2 ORDER BY 3 DESC""").fetchall())
print("M14 lots:",db.execute("SELECT e.lot_file_norm, COUNT(*), COUNT(DISTINCT e.volume_id||'/'||e.document_id) FROM external_citations e JOIN core c ON c.volume_id=e.volume_id AND c.document_id=e.document_id WHERE e.lot_file_norm IS NOT NULL GROUP BY 1 ORDER BY 1").fetchall())
print("M14 earliest external_citation date corpus-wide:",db.execute("SELECT MIN(dd.date_iso) FROM external_citations e JOIN document_dates dd ON dd.volume_id=e.volume_id AND dd.document_id=e.document_id").fetchone())
# M13 came-from
print("M13 rows:",db.execute("SELECT COUNT(*) FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id JOIN document_cache d ON d.volume_id=s.volume_id AND d.document_id=s.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0").fetchone())
print("M13 era:",db.execute("SELECT s.citation_era, COUNT(*) FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id JOIN document_cache d ON d.volume_id=s.volume_id AND d.document_id=s.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY 1 ORDER BY 2 DESC").fetchall())
print("M13 record groups:",db.execute("SELECT s.record_group, COUNT(*) FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id GROUP BY 1 ORDER BY 2 DESC").fetchall())
print("M13 decimal classes:",db.execute("SELECT s.decimal_class, COUNT(*) FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id WHERE s.decimal_class IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 16").fetchall())
print("M13 decimal rows by year<=1949 vs >1949:",db.execute("""SELECT CASE WHEN dd.date_iso<='1949-12-31' THEN 'to1949' ELSE 'after' END, s.citation_era, COUNT(*) FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id JOIN document_dates dd ON dd.volume_id=s.volume_id AND dd.document_id=s.document_id GROUP BY 1,2 ORDER BY 1,3 DESC""").fetchall())
print("M13 named series/lots:",db.execute("SELECT s.repository, s.record_group, s.series_name, s.lot_file_norm, COUNT(*) FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id WHERE s.citation_era IN ('structured','subject_numeric','cfpf','lot_file','named_series','published','unrecognized') GROUP BY 1,2,3,4 ORDER BY 5 DESC").fetchall())
print("M13 came-from lots:",db.execute("SELECT s.lot_file_norm, s.lot_file, COUNT(*) FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id WHERE s.lot_file_norm IS NOT NULL GROUP BY 1,2").fetchall())
# M17 editorial note search
print("M17 acheson search:",db.execute("SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH 'recogn* AND acheson AND september' AND d.volume_id='frus1949v02' AND d.is_editorial_note=1").fetchone())
# chapter titles named in the overview
for v,sub in [("frus1930v03","Revolution in Peru"),("frus1931v02","Revolution in Peru"),("frus1932v05","Refusal of the United States to recognize the Martínez"),("frus1945v09","recognition of the Venezuelan revolutionary junta")]:
    print("chapter check",v,sub,"->",[k[1][:120] for k in chap_docs if k[0]==v and sub in k[1]][:2])
