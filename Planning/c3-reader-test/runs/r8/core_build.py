import sqlite3,json,re,collections,sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
# ---- 1. curated episode chapters: (volume, substring that identifies the chapter path) ----
CH=[
("frus1895p1","Recognition of de facto government"),("frus1899","Revolution in Venezuela and recognition"),("frus1900","Recognition of new Government of Colombia"),("frus1900","Dominican Republic > Recognition of new Government"),
("frus1903","Revolution in Santo Domingo, and recognition"),("frus1903","Revolution in Honduras, and recognition"),("frus1904","Recognition of the provisional government of the Dominican"),
("frus1907p2","Recognition of the provisional Government of Honduras"),("frus1911","Recognition by the United States of the Leconte"),("frus1911","Recognition of Provisional President Estrada"),("frus1911","Honduras: > Revolution; friendly mediation"),
("frus1912","Death of President Leconte and recognition"),("frus1912","Paraguay: > Political affairs: insurrection"),("frus1913","Recognition of President Plaza"),("frus1913","seizure of the executive power by General Hue"),("frus1913","Messages of the de facto Provisional President"),
("frus1914","Constitutionalist revolution against Gen. Huerta"),("frus1914","Peru: > Political affairs: Revolution; resignation of President Billinghurst"),("frus1915","Mexico: > Political affairs: Provincial presidencies"),
("frus1916","Dominican Republic: > Political affairs. Revolutionary movements"),("frus1917","Costa Rica: > Political affairs. Revolution; overthrow"),("frus1918","Continuance of the Tinoco Government"),("frus1919v01","Surrender of power by the Tinocos"),
("frus1919v02","Honduras: > Political affairs > Arbitrary rule"),("frus1919v02","Overthrow of President Pardo"),("frus1920v01","Coup d’état by the Republican Party"),("frus1920v01","Recognition of the Government of Costa Rica"),
("frus1920v02","Fall of the Estrada Cabrera government"),("frus1920v03","Question of the recognition of the Provisional Government by the United States > Informal"),("frus1920v03","Recognition of the Leguia government"),
("frus1921v01","Recognition of the Saavedra Government"),("frus1921v02","Guatemala: > Overthrow of President Herrera"),("frus1921v02","Question of the recognition of the Government of General Obregon"),("frus1921v02","Attitude of other governments toward recognition of the Obregon"),
("frus1922v02","Recognition of the Orellana government"),("frus1922v02","Question of the recognition of the government of General Obregon"),("frus1922v02","Attitude of other governments toward recognition of the Obregon"),("frus1923v02","Recognition of the Government of General Obregón"),
("frus1924v02","Intimation by the United States to President Martinez"),("frus1925v02","Withholding of recognition by the United States of the revolutionary government in Ecuador"),("frus1928v02","Extension by the United States of de jure recognition to the Government of Ecuador"),
("frus1930v01","Argentina: > Revolution in Argentina"),("frus1930v01","Bolivia: > Revolution in Bolivia"),("frus1930v01","Brazil: > Revolution in Brazil"),("frus1930v02","Revolution in the Dominican Republic"),("frus1930v03","Guatemala: > Revolution in Guatemala"),("frus1930v03","Peru: > Revolution in Peru"),
("frus1931v01","Chile: > Revolution in Chile"),("frus1931v02","El Salvador: > Revolution in El Salvador"),("frus1931v02","Recognition of constitutional government in Guatemala"),("frus1931v02","Panama: > Revolution in Panama"),("frus1931v02","Peru: > Revolution in Peru"),
("frus1932v05","Chile: > Revolutions in Chile"),("frus1932v05","Refusal of the United States to recognize the Martínez"),("frus1933v05","Refusal of the United States to recognize the Martínez"),("frus1933v05","II. Government of President Céspedes"),("frus1933v05","III. The Regime of Grau San Martín"),
("frus1934v05","Recognition of the Provisional Government of Cuba"),("frus1934v05","Recognition of the Martínez Government"),("frus1935v04","Ecuador: > Revolution in Ecuador"),("frus1936v05","no longer be guided by article II"),("frus1936v05","Bolivia: > Revolution in Bolivia"),("frus1936v05","Paraguay: > Revolution in Paraguay"),
("frus1937v05","recognition of the Busch Government"),("frus1937v05","recognition of the Enriquez Government"),("frus1937v05","recognition of the Paiva Government"),("frus1940v05","Refusal of the United States to indicate whether it would or would not recognize"),
("frus1943v05","recognition of the Government of General Pedro P. Ramirez"),("frus1943v05","Non-recognition by the United States of the revolutionary regime established in Bolivia"),
("frus1944v07","Withholding of recognition from the regime of Edelmiro Farrell"),("frus1944v07","revolutionary junta in Bolivia"),("frus1944v07","Recognition by the United States and the other American Republics of the new government of Ecuador"),("frus1944v07","Revolutions in El Salvador; policies"),("frus1944v07","Revolution in Guatemala and recognition"),
("frus1945v09","recognition of the Farrell government"),("frus1945v09","government of Osmín Aguirre"),("frus1945v09","recognition of the Venezuelan revolutionary junta"),
("frus1946v11","Bolivian revolution and the problem of recognition"),("frus1946v11","United States recognition of the new Haitian Government"),("frus1947v08","Mancheno, the Suarez, and the Arosemena"),("frus1947v08","nonintervention and nonrecognition"),
("frus1948v09","Continuance by the United States of diplomatic relations with new governments on the basis of the Bogota"),("frus1949v02","Panama: > Political and military relations"),("frus1949v02","Paraguay: > Political relations"),("frus1950v02","Recognition by the United States of the military junta government of Haiti"),
]
# post-1950 episode ranges, bracketed by hand from scope_hits (vol, prefix, lo, hi, label)
RANGES=[("frus1958-60v05mSupp","es_d",28,44,"El Salvador 1960 junta"),("frus1961-63v12","d",415,427,"Peru 1962 junta"),("frus1961-63v12","d",355,363,"Dominican Republic 1963 triumvirate"),
("frus1961-63v10-12mSupp","d",158,167,"Honduras 1963 coup"),("frus1964-68v31","d",127,143,"Argentina 1966 Onganía"),("frus1964-68v31","d",509,518,"Peru 1968 Velasco"),
("frus1969-76v21","d",348,361,"Chile 1973 junta"),("frus1977-80v24","d",133,160,"Bolivia 1978-1980 coups")]
paths={}; chap_docs=collections.defaultdict(list)
def walk(vid,sec,path):
    t=" ".join((sec.get("title") or "").split()); p=path+[t] if t else path
    full=" > ".join(p)
    for d in sec.get("documentIds",[]): paths[(vid,d)]=full; chap_docs[(vid,full)].append(d)
    for s in sec.get("subsections",[]): walk(vid,s,p)
vols=sorted(set(v for v,_ in CH)|set(r[0] for r in RANGES))
for vid,sj in db.execute("SELECT volume_id, structure_json FROM volume_structures WHERE volume_id IN (%s)"%",".join("'%s'"%v for v in vols)):
    for s in json.loads(sj).get("sections",[]): walk(vid,s,[])
core={}  # (vol,doc)->label
missing=[]
for v,sub in CH:
    hits=[(k,ds) for k,ds in chap_docs.items() if k[0]==v and sub in k[1]]
    if not hits: missing.append((v,sub)); continue
    for (vv,full),ds in hits:
        for d in ds: core.setdefault((vv,d),full)
for v,pre,lo,hi,label in RANGES:
    for (vv,d),full in paths.items():
        if vv==v and d.startswith(pre) and d[len(pre):].isdigit() and lo<=int(d[len(pre):])<=hi: core.setdefault((vv,d),label+" | "+full)
print("chapter selectors not found:",missing)
# verify in document_cache, drop apparatus, attach dates
db.execute("CREATE TEMP TABLE core(volume_id TEXT, document_id TEXT, label TEXT, PRIMARY KEY(volume_id,document_id))")
db.executemany("INSERT INTO core VALUES(?,?,?)",[(v,d,l) for (v,d),l in core.items()])
rows=db.execute("""SELECT c.volume_id,c.document_id,dd.date_iso,d.is_editorial_note,length(d.body_text),c.label FROM core c JOIN document_cache d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
LEFT JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE d.is_front_matter=0 ORDER BY c.volume_id,c.document_id""").fetchall()
with open("core_scope.tsv","w") as f:
    for r in rows: f.write("\t".join("" if x is None else str(x) for x in r)+"\n")
n_all=len(rows); n_ed=sum(1 for r in rows if r[3]); core_rows=[r for r in rows if not r[3]]
print(f"core slots {len(core)}; in document_cache non-front-matter {n_all}; editorial notes {n_ed}; core non-apparatus {len(core_rows)} in {len(set(r[0] for r in core_rows))} volumes")
dec=collections.Counter(r[2][:3]+"0s" for r in core_rows if r[2]); print("undated:",sum(1 for r in core_rows if not r[2]))
la=set(l.split("\t")[0] for l in open("la_volumes.tsv"))
basela=dict(db.execute("SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso IS NOT NULL AND d.volume_id IN (%s) GROUP BY 1"%",".join("'%s'"%v for v in la)).fetchall())
with open("core_decades.tsv","w") as f:
    f.write("decade\tcore_docs\tLA_dated_nonapparatus\tper1000\n")
    for k in sorted(dec): f.write(f"{k}\t{dec[k]}\t{basela.get(k,0)}\t{1000*dec[k]/basela[k]:.1f}\n"); print(k,dec[k],basela.get(k,0),f"{1000*dec[k]/basela[k]:.1f}")
# ---- 2. phrase families inside the core, FTS count + literal shares ----
PH={"international obligations":('"international obligations"',r"international obligations",r"international[\s,\-\.\(\)]+obligations?"),
"de facto":('"de facto"',r"de facto",r"de[\s\-]+facto"),
"free elections":('"free elections" OR "free election"',r"free elections?",r"free[\s,\-\.\(\)]+elections?"),
"constitutional government":('"constitutional government"',r"constitutional government",r"constitutional(?:ly)?[\s,\-\.\(\)]+governments?"),
"recognition":('recognition',r"recognition",r"recogni(?:[sz]e|[sz]ed|[sz]es|[sz]ing|tion|tions)"),
"consult":('consult*',r"consult",r"consult(?:ation|ations|ed|ing|s)?"),
"withhold recognition":('NEAR(withhold recognition, 4) OR NEAR(withheld recognition, 4) OR NEAR(withholding recognition, 4)',r"withh(?:old|eld|olding) recognition",r"withh(?:old|eld|olding)[\s,\-\.\(\)]+(?:\w+[\s,\-\.\(\)]+){0,3}recognition"),
"Department of State (control)":('"department of state"',r"Department of State",r"Department[\s,\-\.\(\)]+of[\s,\-\.\(\)]+State"),
"ZZZ_IMPOSSIBLE_ZZZ (control)":('ZZZ_IMPOSSIBLE_ZZZ',r"ZZZ_IMPOSSIBLE_ZZZ",r"ZZZ_IMPOSSIBLE_ZZZ")}
out=[]
for name,(q,strict,tol) in PH.items():
    hits=db.execute("""SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN core c ON c.volume_id=d.volume_id AND c.document_id=d.document_id
      WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.volume_id,d.document_id""",(q,)).fetchall()
    n=len(hits)
    if n==0: out.append((name,q,0,0,0,0,0)); print(name,"FTS hits in core: 0"); continue
    k=n if n<300 else 40
    idx=[round(i*(n-1)/(k-1)) for i in range(k)] if k>1 else [0]
    sample=[hits[i] for i in idx]
    s_ok=t_ok=0
    for v,d in sample:
        r=db.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        txt=" ".join(" ".join(x or "" for x in r).split())
        if re.search(strict,txt): s_ok+=1
        if re.search(tol,txt,re.I): t_ok+=1
    out.append((name,q,n,len(sample),s_ok,t_ok,len(core_rows)))
    print(f"{name}: FTS hits in core {n} of {len(core_rows)}; literal STRICT {s_ok} of {len(sample)}; TOLERANT {t_ok} of {len(sample)}")
with open("core_phrase_shares.tsv","w") as f:
    f.write("family\tfts_query\tfts_hits_in_core\tsample\tstrict_hits\ttolerant_hits\tcore_size\n")
    for o in out: f.write("\t".join(map(str,o))+"\n")
# corpus-wide control share for false-friend test
tot=db.execute("SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0").fetchone()[0]
for name in ["international obligations","de facto","recognition","Department of State (control)"]:
    q=PH[name][0]
    c=db.execute("SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0",(q,)).fetchone()[0]
    print(f"corpus-wide {name}: {c} of {tot}")
# ---- 3. archival channels over the core ----
print("--- came-from (document_sources) over core, by citation_era / repository / series")
for r in db.execute("""SELECT s.citation_era, COUNT(*) FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id JOIN document_cache d ON d.volume_id=s.volume_id AND d.document_id=s.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY 1 ORDER BY 2 DESC"""): print("  era",r)
cf=db.execute("""SELECT COALESCE(s.repository,'?'), COALESCE(s.record_group,'?'), COALESCE(s.series_name, s.lot_file, s.decimal_class, '?'), COUNT(*) FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id JOIN document_cache d ON d.volume_id=s.volume_id AND d.document_id=s.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY 1,2,3 ORDER BY 4 DESC LIMIT 25""").fetchall()
with open("core_came_from.tsv","w") as f:
    for r in cf: f.write("\t".join(map(str,r))+"\n"); print("  ",r)
nsrc=db.execute("SELECT COUNT(*) FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id JOIN document_cache d ON d.volume_id=s.volume_id AND d.document_id=s.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0").fetchone()[0]
print("core docs with a document_sources row:",nsrc,"of",len(core_rows))
print("--- pointed-at (external_citations) over core, by repository / collection")
pa=db.execute("""SELECT COALESCE(e.repository,'?'), COALESCE(e.collection,'?'), COUNT(*), COUNT(DISTINCT e.volume_id||'/'||e.document_id) FROM external_citations e JOIN core c ON c.volume_id=e.volume_id AND c.document_id=e.document_id JOIN document_cache d ON d.volume_id=e.volume_id AND d.document_id=e.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY 1,2 ORDER BY 3 DESC LIMIT 25""").fetchall()
with open("core_pointed_at.tsv","w") as f:
    for r in pa: f.write("\t".join(map(str,r))+"\n"); print("  ",r)
ne=db.execute("SELECT COUNT(*), COUNT(DISTINCT e.volume_id||'/'||e.document_id) FROM external_citations e JOIN core c ON c.volume_id=e.volume_id AND c.document_id=e.document_id").fetchone()
print("external_citations rows over core:",ne)
lots=db.execute("""SELECT e.lot_file_norm, COUNT(*) FROM external_citations e JOIN core c ON c.volume_id=e.volume_id AND c.document_id=e.document_id WHERE e.lot_file_norm IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 15""").fetchall()
print("pointed-at lots:",lots)
lots2=db.execute("""SELECT s.lot_file_norm, COUNT(*) FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id WHERE s.lot_file_norm IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 15""").fetchall()
print("came-from lots:",lots2)
dcl=db.execute("""SELECT s.decimal_class, COUNT(*) FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id WHERE s.decimal_class IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 15""").fetchall()
print("came-from decimal classes:",dcl)
json.dump({"lots_pointed":lots,"lots_came":lots2,"decimal_came":dcl},open("core_archival_keys.json","w"))
