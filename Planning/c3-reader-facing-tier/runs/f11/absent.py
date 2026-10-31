import sqlite3,json
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open("scope_vols.txt")]
PDV=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30','frus1955-57v09','frus1961-63v25']
REG=[v for v in vols if v not in PDV]; ph=",".join("?"*len(REG))
Q="SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND d.is_front_matter=0 AND d.is_editorial_note=0"%ph
for t in ['"soft power"','NEAR(soft power, 3)','"Asia Foundation"','Fulbright','"Peace Corps"','"Radio Free Asia"','"cultural exchange"','"educational exchange"','"opinion poll" OR "opinion survey" OR "public opinion poll"','"USIS" AND (poll OR survey)','"Radio Peking" OR "Peking Radio"','"hearts and minds"']:
    print("REG",t,"->",db.execute(Q,[t]+REG).fetchone()[0])
sf=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/series-facts-index.json"))["byNaId"]
n=len(sf); pre=sum(1 for v in sf.values() if v.get("y0") and v["y0"]<1940); nodate=sum(1 for v in sf.values() if not v.get("y0"))
print("series-facts: %d series; start before 1940: %d ; no start year: %d"%(n,pre,nodate))
for naid in ["1102141","42125423","40967285","1257679","40943515"]:
    v=sf.get(naid); print(naid, v)
