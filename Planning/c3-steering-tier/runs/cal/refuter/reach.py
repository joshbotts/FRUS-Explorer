import sqlite3, json, re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
cited=[tuple(x) for x in json.load(open('cited_pairs.json'))['cited']]
EXC=" AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
FIND="""SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
 LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
 WHERE frus_documents MATCH ? """+EXC+""" AND dd.date_iso >= ? AND dd.date_iso < ? ORDER BY bm25(frus_documents)"""
# the find.py calls as the log reconstructs them (query, lo, hi, limit)
finds=[
 ('cuba AND (annex* OR possess* OR acquisition OR "key to the gulf")','1865','1895',25),
 ('cuba AND (annex* OR possess* OR acquisition OR "key to the gulf")','1865','1895',12),
 ('cuba AND sugar AND (reciprocity OR tariff OR duties OR commerce)','1875','1898',22),
 ('cuba AND (insurrection OR belligerency) AND (...) AND ($ OR millions)','1895','1898',15),
 ('cuba AND ("naval stations" OR "coaling stations" OR platt OR "independence of cuba") AND (security OR defense OR protection OR safety)','1898','1912',20),
 ('guantanamo AND (naval OR coaling)','1898','1925',15),
 ('cuba AND ("american investments" OR "american capital" OR "american interests") AND sugar AND (million* OR billion*)','1910','1935',20),
 ('cuba AND intervention AND (policy OR principle) AND ("platt amendment" OR "third article" OR "treaty of relations")','1925','1936',14),
 ('cuba AND (bases OR "air bases") AND (strategic OR defense OR security) AND ("Guantanamo" OR "San Antonio")','1939','1950',12),
 ('cuba AND missiles AND ("balance of power" OR "strategic balance" OR "political" ) AND ("no great difference" OR "strategic" )','1962-10-14','1962-10-30',15),
 ('cuba AND missiles','1962-10-16','1962-10-17',10),
 ('cuba AND ("a missile is a missile" OR "geopolitical" OR "politically")','1962-10-16','1962-10-19',6),
 ('cuba AND cuban AND (threat OR subversion OR "national security" OR hemisphere)','1981','1989',14),
 ('cuba AND (investment* OR sugar) AND ("national security" OR strategic OR defense) AND (stability OR stable)','1950','1959',14),
 ('cuba AND ("sugar act" OR "sugar quota") AND (castro OR revolution)','1959','1961',8),
 ('cuba AND (burden OR liability OR drain) AND (soviet OR russians) AND (economy OR economic OR subsidy)','1964','1981',12),
 ('cuba AND (normalization OR "normalizing") AND (embargo OR trade) AND (interest* OR benefit*)','1974','1981',12),
 ('cuba AND sugar AND (war OR defense OR submarines OR shipping) AND ("entire" OR "purchase")','1941','1945',8),
 ('cuba AND (sugar OR investments) AND (intervention OR intervene) AND (property OR interests)','1915','1925',6),
 ('cuba AND machado AND (sugar OR investments OR property) AND (intervention OR chaos OR anarchy)','1933','1934',6),
]
hits_all={p:[] for p in cited}; hits_lim={p:[] for p in cited}
for i,(q,lo,hi,lim) in enumerate(finds,1):
    try:
        rows=db.execute(FIND,(q,lo,hi)).fetchall()
    except Exception as e:
        print(f"F{i:02d} ERROR {e} | {q[:70]}"); continue
    top=rows[:lim]
    print(f"F{i:02d} n={len(rows):5d} top{lim}: " + ", ".join(f"{v}/{d}" for v,d in top[:lim]) + f" | {q[:60]} [{lo},{hi})")
    for p in cited:
        if p in rows: hits_all[p].append(f"F{i:02d}")
        if p in top: hits_lim[p].append(f"F{i:02d}")
# header/dateline FTS, pre-1895 (no Ed2 clause in the log's version), LIMIT 60 and unlimited
H1="""SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH '{header dateline}:(cuba OR cuban OR havana OR habana OR virginius)' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso < '1895' ORDER BY dd.date_iso"""
rows=db.execute(H1).fetchall(); print("H1 header/dateline pre-1895 n=",len(rows))
for p in cited:
    if p in rows: hits_all[p].append("H1"); 
    if p in rows[:60]: hits_lim[p].append("H1")
H2="""SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '{header dateline} : (cuba OR cuban OR havana OR habana OR guantanamo)'"""+EXC
rows=set(db.execute(H2).fetchall()); print("H2 header/dateline all dates n=",len(rows))
for p in cited:
    if p in rows: hits_all[p].append("H2(count-only)")
B="""SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '(cuba OR cuban OR cubans OR havana OR habana)'"""+EXC
rows=set(db.execute(B).fetchall()); print("Scope B n=",len(rows))
for p in cited:
    if p in rows: hits_all[p].append("ScopeB")
V="""SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH 'cuba OR cuban OR havana' AND d.is_front_matter=0 AND d.is_editorial_note=0"""
rows=set(db.execute(V).fetchall()); print("per-volume 'cuba OR cuban OR havana' n=",len(rows))
for p in cited:
    if p in rows: hits_all[p].append("V(count-only)")
setA={}
for line in open('setA.tsv'):
    v,d,dt,t=line.rstrip('\n').split('\t'); setA[(v,d)]=t
print()
print("=== per cited document: strict reach ===")
strict_vec=[]; untraced=[]
for p in cited:
    inA=p in setA
    anyq=bool(hits_all[p]) or inA
    print(f"{p[0]}/{p[1]:6} ScopeA={'Y' if inA else '-'} unlimited={hits_all[p]} within-limit={hits_lim[p]}  => {'REACHED' if anyq else 'NOT RETURNED BY ANY LOGGED QUERY'}")
    if not anyq: untraced.append(p)
print("not returned by any logged full-text/heading query or scope set:",untraced)
# FTS columns and the word check for d112
print("fts columns:", [c[1] for c in db.execute("pragma table_info(frus_documents)")])
r=db.execute("select header, dateline, substr(source_note,1,200), length(body_text), instr(lower(header||' '||coalesce(dateline,'')||' '||coalesce(source_note,'')||' '||body_text),'cuba'), instr(lower(body_text),'havana'), instr(lower(body_text),'habana') from document_cache where volume_id='frus1958-60v05' and document_id='d112'").fetchone()
print("d112:",r)
