import sqlite3,re,collections
RUN="/Users/jbotts/frus-analysis/c3/runs/r11/"
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
S=sorted(set(tuple(l.split()) for l in open(RUN+"scope_final.tsv")))
print("scope_final.tsv distinct pairs",len(S),"volumes",len({v for v,_ in S}),"Ed2 volumes",[v for v,_ in S if v.endswith("Ed2")])
con.execute("CREATE TEMP TABLE scope(volume_id TEXT, document_id TEXT, PRIMARY KEY(volume_id,document_id))")
con.executemany("INSERT INTO scope VALUES(?,?)",S)
q=lambda s,p=(): con.execute(s,p).fetchall()
print("scope rows in document_cache / apparatus among them:", q("SELECT COUNT(*), SUM(c.is_front_matter), SUM(c.is_editorial_note) FROM scope s JOIN document_cache c USING(volume_id,document_id)"))
# --- Path A re-derivation from chap_docs.tsv (the session's TEI scan output) + my own FTS run
BAD=re.compile(r'Proposed changes in the regime of the Mixed Courts|divest his government|The war prior to the entrance')
rows=[l.rstrip("\n").split("\t") for l in open(RUN+"chap_docs.tsv")]
keep=[(v,d) for v,d,c in rows if not BAD.search(c)]
print("chap_docs rows",len(rows),"after false-chapter removal",len(keep),"distinct",len(set(keep)))
con.execute("CREATE TEMP TABLE chap(volume_id TEXT, document_id TEXT)"); con.executemany("INSERT INTO chap VALUES(?,?)",keep)
print("chap non-apparatus:", q("SELECT COUNT(*) FROM chap h JOIN document_cache c USING(volume_id,document_id) WHERE c.is_front_matter=0 AND c.is_editorial_note=0"))
A=set(q("SELECT DISTINCT h.volume_id,h.document_id FROM chap h JOIN document_cache c USING(volume_id,document_id) JOIN frus_documents f ON f.volume_id=h.volume_id AND f.document_id=h.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND frus_documents MATCH 'recogni*'"))
print("Path A (chap AND recogni*, non-apparatus):",len(A),"volumes",len({v for v,_ in A}))
sA=set(tuple(l.split("\t")[:2]) for l in open(RUN+"scopeA.tsv"))
print("  equals scopeA.tsv:",A==sA, len(sA))
# --- Path B
NEARQ=open(RUN+"nearq.txt").read().strip()
hits=q("SELECT f.volume_id,f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0",(NEARQ,))
print("NEAR hits non-apparatus corpus-wide:",len(hits))
mod=[x.strip().strip("'") for x in open(RUN+"modvols.txt").read().split(",")]
lat=set(tuple(l.split("\t")[:2]) for l in open(RUN+"latam_docs.tsv"))
print("latam_docs.tsv pairs",len(lat),"modvols",len(mod))
B=set((v,d) for v,d in hits if ((v,d) in lat or v in mod) and (v,d) not in A and not v.endswith("Ed2"))
sB=set(tuple(l.split("\t")[:2]) for l in open(RUN+"scopeB.tsv"))
print("Path B:",len(B),"equals scopeB.tsv:",B==sB,len(sB))
C={("frus1913","d7"),("frus1949v02","d454")}
U=A|B|C
print("A|B|C:",len(U),"volumes",len({v for v,_ in U}),"equals scope_final:",U==set(S), "C overlaps A/B:", C&(A|B))
# Path C provenance
print("C1 phrase search:", q("SELECT volume_id,document_id FROM frus_documents WHERE frus_documents MATCH '\"cooperation is possible only when supported\" OR \"just government based upon law\"'"))
print("C2 phrase search:", q("SELECT f.volume_id,f.document_id FROM frus_documents f JOIN document_cache c USING(volume_id,document_id) WHERE frus_documents MATCH '\"does not imply any judgment\"' AND c.is_front_matter=0"))
# --- date span
print("scope date span:", q("SELECT MIN(d.date_iso), MAX(d.date_iso), COUNT(*), SUM(d.date_iso IS NULL) FROM scope s LEFT JOIN document_dates d USING(volume_id,document_id)"))
print("  min/max pairs:", q("SELECT s.volume_id,s.document_id,d.date_iso FROM scope s JOIN document_dates d USING(volume_id,document_id) ORDER BY d.date_iso LIMIT 2"), q("SELECT s.volume_id,s.document_id,d.date_iso FROM scope s JOIN document_dates d USING(volume_id,document_id) ORDER BY d.date_iso DESC LIMIT 2"))
# --- decades
den=dict(q("SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_dates dd JOIN document_cache c ON c.volume_id=dd.volume_id AND c.document_id=dd.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND dd.date_iso IS NOT NULL AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') GROUP BY 1"))
num=dict(q("SELECT substr(d.date_iso,1,3)||'0s', COUNT(*) FROM scope s JOIN document_dates d USING(volume_id,document_id) GROUP BY 1"))
for k in sorted(num): print("  %s scope %d of %d = %.2f/1000"%(k,num[k],den[k],1000*num[k]/den[k]))
print("1980s corpus dated non-apparatus (Ed2 excluded):",den.get('1980s'), "; with Ed2:", q("SELECT COUNT(*) FROM document_dates dd JOIN document_cache c USING(volume_id,document_id) WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND dd.date_iso BETWEEN '1980-01-01' AND '1989-12-31'"))
# --- came-from
print("CAME-FROM rows for scope:", q("SELECT COUNT(*) FROM scope s JOIN document_sources ds USING(volume_id,document_id)"))
print("  citation_era:", q("SELECT citation_era, COUNT(*) FROM scope s JOIN document_sources ds USING(volume_id,document_id) GROUP BY 1 ORDER BY 2 DESC"))
print("  record_group:", q("SELECT record_group, COUNT(*) FROM scope s JOIN document_sources ds USING(volume_id,document_id) GROUP BY 1 ORDER BY 2 DESC"))
print("  decimal-era docs date span:", q("SELECT MIN(d.date_iso),MAX(d.date_iso),COUNT(*) FROM scope s JOIN document_sources ds USING(volume_id,document_id) JOIN document_dates d USING(volume_id,document_id) WHERE ds.citation_era='decimal'"))
print("  RG59 docs date span:", q("SELECT MIN(d.date_iso),MAX(d.date_iso),COUNT(*) FROM scope s JOIN document_sources ds USING(volume_id,document_id) JOIN document_dates d USING(volume_id,document_id) WHERE ds.record_group='59'"))
print("  decimal AND RG59:", q("SELECT COUNT(*) FROM scope s JOIN document_sources ds USING(volume_id,document_id) WHERE ds.citation_era='decimal' AND ds.record_group='59'"))
print("  repository Department of State:", q("SELECT COUNT(*) FROM scope s JOIN document_sources ds USING(volume_id,document_id) WHERE ds.repository='Department of State'"))
# Government vs Political affairs among decimal rows dated 1910-1949
rows=q("SELECT ds.decimal_class, substr(d.date_iso,1,4) FROM scope s JOIN document_sources ds USING(volume_id,document_id) LEFT JOIN document_dates d USING(volume_id,document_id) WHERE ds.citation_era='decimal' AND ds.decimal_class IS NOT NULL AND ds.decimal_class<>''")
print("  decimal rows with class:",len(rows))
gl=[(c,y) for c,y in rows if y and '1910'<=y<='1949']
print("  dated 1910-1949:",len(gl),"outside:",len(rows)-len(gl))
key=collections.Counter()
gov=pol=cls7=0
for c,y in gl:
    m=re.match(r'^(\d)(\d\d[a-z]?)\.(\w+)',c)
    if not m: key[(c,'unparsed')]+=1; continue
    k=m.group(1)+m.group(2)+"."+m.group(3)[:2]; key[k]+=1
    if m.group(1)=='8' and m.group(3)[:2]=='01': gov+=1
    if m.group(1)=='8' and m.group(3)[:2]=='00': pol+=1
    if m.group(1)=='7': cls7+=1
print("  8xx.01 Government:",gov," 8xx.00 Political affairs:",pol," class 7:",cls7," parsed total:",sum(v for k,v in key.items() if not isinstance(k,tuple)))
print("  top keys:",key.most_common(10))
# all decimal rows regardless of date, key prefix counts (to test the ranking claim without the date gate)
allkey=collections.Counter()
for c,y in rows:
    m=re.match(r'^(\d)(\d\d[a-z]?)\.(\w+)',c)
    if m: allkey[m.group(1)+m.group(2)+"."+m.group(3)[:2]]+=1
print("  top keys, all dates:",allkey.most_common(10))
# --- pointed-at
print("POINTED-AT inherited=0 rows / docs:", q("SELECT COUNT(*), COUNT(DISTINCT s.volume_id||'/'||s.document_id) FROM scope s JOIN external_citations e USING(volume_id,document_id) WHERE e.inherited=0"))
print("  anchors:", q("SELECT anchor, COUNT(*) FROM scope s JOIN external_citations e USING(volume_id,document_id) WHERE e.inherited=0 GROUP BY 1"))
print("  incl. inherited rows/docs:", q("SELECT COUNT(*), COUNT(DISTINCT s.volume_id||'/'||s.document_id) FROM scope s JOIN external_citations e USING(volume_id,document_id)"))
print("  earliest external_citations document date corpus-wide:", q("SELECT MIN(d.date_iso) FROM external_citations e JOIN document_dates d USING(volume_id,document_id)"), " earliest with inherited=0:", q("SELECT MIN(d.date_iso) FROM external_citations e JOIN document_dates d USING(volume_id,document_id) WHERE e.inherited=0"))
print("  earliest scope pointed-at:", q("SELECT MIN(d.date_iso) FROM scope s JOIN external_citations e USING(volume_id,document_id) JOIN document_dates d USING(volume_id,document_id) WHERE e.inherited=0"))
# --- Estrada
print("Estrada doctrine FTS rows:", q("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH '\"Estrada doctrine\"'"), " non-apparatus:", q("SELECT COUNT(*) FROM frus_documents f JOIN document_cache c USING(volume_id,document_id) WHERE frus_documents MATCH '\"Estrada doctrine\"' AND c.is_front_matter=0 AND c.is_editorial_note=0"), " in Ed2 volumes:", q("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH '\"Estrada doctrine\"' AND volume_id LIKE '%Ed2'"))
print("  earliest:", q("SELECT f.volume_id,f.document_id,d.date_iso,c.is_editorial_note FROM frus_documents f JOIN document_cache c USING(volume_id,document_id) LEFT JOIN document_dates d USING(volume_id,document_id) WHERE frus_documents MATCH '\"Estrada doctrine\"' ORDER BY d.date_iso LIMIT 3"))
print("  Estrada AND recogni* dated 1929-01-01..1931-06-30 non-apparatus:", q("SELECT f.volume_id,f.document_id,d.date_iso FROM frus_documents f JOIN document_cache c USING(volume_id,document_id) JOIN document_dates d USING(volume_id,document_id) WHERE frus_documents MATCH 'Estrada AND recogni*' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso BETWEEN '1929-01-01' AND '1931-06-30' ORDER BY d.date_iso"))
print("  same, apparatus allowed (log's form, is_front_matter=0 only):", q("SELECT COUNT(*) FROM frus_documents f JOIN document_cache c USING(volume_id,document_id) JOIN document_dates d USING(volume_id,document_id) WHERE frus_documents MATCH 'Estrada AND recogni*' AND c.is_front_matter=0 AND d.date_iso BETWEEN '1929-01-01' AND '1931-06-30'"))
print("NEAR(recogni* states governments,4) >=1969 non-apparatus:", q("SELECT f.volume_id||'/'||f.document_id, d.date_iso FROM frus_documents f JOIN document_cache c USING(volume_id,document_id) JOIN document_dates d USING(volume_id,document_id) WHERE frus_documents MATCH 'NEAR(recogni* states governments, 4)' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso>='1969-01-01' ORDER BY d.date_iso"))
# --- by force false friend
chapNA=set(q("SELECT h.volume_id,h.document_id FROM chap h JOIN document_cache c USING(volume_id,document_id) WHERE c.is_front_matter=0 AND c.is_editorial_note=0"))
NA=set(q("SELECT volume_id,document_id FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0"))
for term in ('recogni*','"by force"','"Department of State"'):
    h=set(q("SELECT volume_id,document_id FROM frus_documents WHERE frus_documents MATCH ?",(term,)))
    print("  %-22s chapters %d of %d (%.3f)  corpus %d of %d (%.3f)"%(term,len(h&chapNA),len(chapNA),len(h&chapNA)/len(chapNA),len(h&NA),len(NA),len(h&NA)/len(NA)))
# --- controls
pos=dict(q("SELECT f.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache c USING(volume_id,document_id) WHERE frus_documents MATCH '\"Department of State\"' AND c.is_front_matter=0 AND c.is_editorial_note=0 GROUP BY 1"))
vols=sorted({v for v,_ in S})
print("controls: positive>0 in",sum(1 for v in vols if pos.get(v,0)>0),"of",len(vols),"min",min((pos.get(v,0),v) for v in vols),"negative",q("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ'"))
print("87 volumes:", vols)
