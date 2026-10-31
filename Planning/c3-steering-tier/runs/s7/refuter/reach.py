import sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
pairs=[("frus1875v01","d199"),("frus1875v02","d393"),("frus1947v07","d582"),("frus1948v07","d43"),("frus1961-63v22","d202"),("frus1961-63v22","d204"),("frus1964-68v04","d215"),("frus1964-68v05","d258"),("frus1969-76ve12","d218"),("frus1969-76ve15p2","d292"),("frus1977-80v03","d152")]
exprs=["corrupt* OR briberi OR bribe* OR graft OR embezzl*","corrupt* OR briberi OR bribe*","corrupt*",'"department of state"',"briberi OR bribe*",'"illicit payments"','"foreign corrupt practices"',"lockheed","graft","embezzl*",'anticorrupt* OR "anti corruption"',"ZZZ_IMPOSSIBLE_ZZZ",'"questionable payments"',"venezuela* AND commission AND (corrupt* OR fraud*)","telegram","somoza AND corrupt*","lockheed AND (briberi OR bribe* OR payment* OR scandal*)","kleptocra*","kickback*","OECD AND (briberi OR bribe*)"]
controls={'"department of state"',"telegram","ZZZ_IMPOSSIBLE_ZZZ"}
substantive_hits={}
for v,d in pairs:
    hits=[]
    for e in exprs:
        n=con.execute("SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.volume_id=? AND c.document_id=? AND c.is_front_matter=0 AND c.is_editorial_note=0",(e,v,d)).fetchone()[0]
        if n: hits.append(e)
    subst=[h for h in hits if h not in controls]
    substantive_hits[(v,d)]=subst
    print("%s/%s: substantive=%d %s | controls=%s"%(v,d,len(subst),subst,[h for h in hits if h in controls]))
print("\nIn set h (corrupt* OR briberi OR bribe*, non-apparatus, no Ed2):")
for v,d in pairs:
    n=con.execute("SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt* OR briberi OR bribe*' AND c.volume_id=? AND c.document_id=? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')",(v,d)).fetchone()[0]
    print(" ",v,d,"in h" if n else "NOT in h")
# Does d204 contain any corruption-family word at all (any stem)? Check raw text with regex
import re
t="".join(x or "" for x in con.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id='frus1961-63v22' AND document_id='d204'").fetchone())
print("\nd204 regex corrupt|brib|graft|embezzl:", re.findall(r'\b\w*(?:corrupt|brib|graft|embezzl)\w*\b',t,re.I))
print("d204 header:", con.execute("SELECT header FROM document_cache WHERE volume_id='frus1961-63v22' AND document_id='d204'").fetchone()[0][:200])
print("d204 mentions Farley?:", bool(re.search(r'Farley',t)))
# Was d204 in any bm25-ranked list the session printed before the neighbour run? The log's per-volume bm25 queries were corrupt* within frus1961-63v22 LIMIT 8:
rows=con.execute("SELECT c.volume_id||'/'||c.document_id, round(bm25(frus_documents),1) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt*' AND c.volume_id='frus1961-63v22' AND c.is_front_matter=0 AND c.is_editorial_note=0 ORDER BY bm25(frus_documents) LIMIT 8").fetchall()
print("\nbm25 corrupt* within frus1961-63v22 LIMIT 8 (log line 256):", rows)
