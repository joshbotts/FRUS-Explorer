import sqlite3,re,collections
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"; RUN="/Users/jbotts/frus-analysis/c3f/runs/f2/"
c=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
scope={l.split("\t")[0]:l.split("\t")[1] for l in open(RUN+"scope_volumes.tsv")}
EA={v for v,k in scope.items() if k=="EA"}; PD={v for v,k in scope.items() if k=="PD"}
cited=[("frus1952-54v12p2","d403"),("frus1952-54v12p2","d352"),("frus1955-57v09","d190"),("frus1917-72PubDipv06","d127"),("frus1917-72PubDipv06","d128"),("frus1961-63v03","d308"),("frus1917-72PubDipv07","d32"),("frus1964-68v29p2","d46"),("frus1917-72PubDipv08","d31"),("frus1917-72PubDipv08","d58"),("frus1917-72PubDipv08","d88"),("frus1969-76v19p2","d67"),("frus1917-72PubDipv08","d149"),("frus1969-76v38p2","d105"),("frus1977-80v30","d2")]
Q={}
# L6: header LIKE scan over PubDip volumes, LIMIT 80 (as logged) and unlimited
sql6="SELECT volume_id, document_id FROM document_cache WHERE volume_id LIKE 'frus1917-72PubDipv0%' AND is_front_matter=0 AND (header LIKE '%Asia%' OR header LIKE '%Japan%' OR header LIKE '%Vietnam%' OR header LIKE '%Far East%' OR header LIKE '%China%' OR header LIKE '%Pacific%' OR header LIKE '%Korea%' OR header LIKE '%Philippin%' OR header LIKE '%Indonesia%')"
Q["L6 header-LIKE PubDip (LIMIT 80, as logged)"]=set(c.execute(sql6+" LIMIT 80").fetchall())
Q["L6 header-LIKE PubDip (no LIMIT)"]=set(c.execute(sql6).fetchall())
# MATCH queries filtered to scope
sqlm="SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0"
terms={"M8/77 Dept of State":'"Department of State"',"M10/62 USIA":'"United States Information Agency" OR USIA',"M11/63 psychological":'"psychological warfare" OR "psychological strategy" OR "psychological operations"',"M12/64 propaganda":'propaganda',"M13/65 image":'"image of the United States" OR "American image" OR "U.S. image"',"M14/66 information program":'"information program"',"M15/67 cultural exchange":'"cultural exchange" OR "exchange of persons"',"M70 opinion research":'(poll OR polls OR survey OR surveys) AND (Japanese OR Korean OR Koreans OR Filipino OR Filipinos OR Thai OR Indonesian OR Indonesians OR Vietnamese) AND (USIA OR USIS OR "Information Agency")',"M75 soft power":'"soft power"',"M76 messaging":'messaging'}
raw={}
for lab,t in terms.items():
    rows=set(c.execute(sqlm,(t,)).fetchall()); raw[lab]=rows
    Q[lab+" (scoped)"]={r for r in rows if r[0] in scope}
# R16 rank_pd: all 968 PD docs ranked; printed top 70; wide set >=10
vols=['frus1917-72PubDip','frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30']
pat=re.compile(r"\b(Japan\w*|Korea\w*|China|Chinese|Taiwan|Vietnam\w*|Viet-Nam\w*|Philippin\w*|Indonesia\w*|Thai\w*|Laos|Lao|Cambodia\w*|Burm\w*|Malaysia\w*|Singapore|East Asia\w*|Far East\w*|Asian?s?|Pacific|Australia\w*|New Zealand|Okinawa\w*|Peking|Hanoi|Saigon|Tokyo)\b")
rows=c.execute("SELECT volume_id, document_id, length(body_text), body_text FROM document_cache WHERE volume_id IN (%s) AND is_front_matter=0 AND is_editorial_note=0"%",".join("?"*6),vols).fetchall()
res=sorted(((len(pat.findall(b)),len(pat.findall(b))*1000/max(L,1),v,d) for v,d,L,b in rows),reverse=True)
rank={(v,d):i+1 for i,(n,dens,v,d) in enumerate(res)}; nmatch={(v,d):n for n,dens,v,d in res}
Q["R16 rank_pd wide set (>=10 matches)"]={(v,d) for n,dens,v,d in res if n>=10}
Q["R16 rank_pd printed top 70"]={(v,d) for n,dens,v,d in res[:70]}
# L17 header LIKE scan filtered to EA volumes
sql17="SELECT volume_id, document_id FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND (header LIKE '%psycholog%' OR header LIKE '%Information Agency%' OR header LIKE '%information program%' OR header LIKE '%propaganda%' OR header LIKE '%Operations Coordinating Board%' OR header LIKE '%USIA%' OR header LIKE '%cultural%')"
r17=set(c.execute(sql17).fetchall()); raw["L17 header-LIKE"]=r17
Q["L17 header-LIKE (EA volumes)"]={r for r in r17 if r[0] in EA}
# B40 BM25 filtered to EA volumes, with rank
sql40="SELECT d.volume_id, d.document_id, bm25(frus_documents) s FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY s ASC"
b40=c.execute(sql40,('(USIS OR USIA OR "information program" OR "information activities") AND (Asian OR Asians) AND (attitude OR attitudes OR image OR prestige)',)).fetchall()
b40ea=[(v,d) for v,d,s in b40 if v in EA]; raw["B40 BM25"]={(v,d) for v,d,s in b40}
Q["B40 BM25 (EA volumes, all %d)"%len(b40ea)]=set(b40ea); Q["B40 BM25 (EA volumes, top 40 read)"]=set(b40ea[:40])
b40rank={p:i+1 for i,p in enumerate(b40ea)}
print("query result-set sizes:"); [print("  %-50s %6d"%(k,len(v))) for k,v in Q.items()]
print("\n== membership of each cited document ==")
for p in cited:
    hits=[k for k,v in Q.items() if p in v]
    extra=""
    if p[0] in PD: extra=" | rank_pd rank %d, matches %d"%(rank.get(p,-1),nmatch.get(p,-1))
    if p in b40rank: extra+=" | BM25 EA rank %d"%b40rank[p]
    print("%s/%s: %d queries return it%s"%(p[0],p[1],len(hits),extra))
    for h in hits: print("      -",h)
    if not hits:
        print("      RETURNED BY NO LOGGED QUERY. Unfiltered (pre-scope) membership:",[k for k,v in raw.items() if p in v])
