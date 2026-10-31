import sqlite3
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
c=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
pairs=[("frus1952-54v12p2","d403"),("frus1952-54v12p2","d352"),("frus1955-57v09","d190"),("frus1917-72PubDipv06","d127"),("frus1917-72PubDipv06","d128"),("frus1961-63v03","d308"),("frus1917-72PubDipv07","d32"),("frus1964-68v29p2","d46"),("frus1917-72PubDipv08","d31"),("frus1917-72PubDipv08","d58"),("frus1917-72PubDipv08","d88"),("frus1969-76v19p2","d67"),("frus1917-72PubDipv08","d149"),("frus1969-76v38p2","d105"),("frus1977-80v30","d2")]
print("== dates and headers of the 15 cited ==")
for v,d in pairs:
    r=c.execute("SELECT t.date_iso, d.is_front_matter, d.is_editorial_note, length(d.body_text), substr(d.header,1,170), substr(d.source_note,1,160) FROM document_cache d LEFT JOIN document_dates t ON t.volume_id=d.volume_id AND t.document_id=d.document_id WHERE d.volume_id=? AND d.document_id=?",(v,d)).fetchone()
    print(v,d,"|",r[0],"| fm",r[1],"en",r[2],"| len",r[3],"|"," ".join((r[4] or "").split()))
    print("     SRC:"," ".join((r[5] or "").split()))
print("\n== min/max date_iso over the 15 ==")
q="SELECT MIN(t.date_iso), MAX(t.date_iso) FROM document_dates t WHERE (t.volume_id, t.document_id) IN (VALUES %s)"%",".join("('%s','%s')"%p for p in pairs)
print(c.execute(q).fetchone())
print("\n== document_sources rows for the 15 ==")
for r in c.execute("SELECT volume_id, document_id, repository, record_group, lot_file_norm, series_name, citation_era FROM document_sources WHERE (volume_id, document_id) IN (VALUES %s) ORDER BY volume_id, document_id"%",".join("('%s','%s')"%p for p in pairs)): print(r)
print("\n== external_citations rows for the 15 ==")
for r in c.execute("SELECT volume_id, document_id, anchor, repository, collection, lot_file_norm, substr(raw_text,1,120) FROM external_citations WHERE (volume_id, document_id) IN (VALUES %s)"%",".join("('%s','%s')"%p for p in pairs)): print(r)
print("\n== external_citations schema and earliest document date among rows (house figure 1910-12-06) ==")
print(c.execute("SELECT sql FROM sqlite_master WHERE name='external_citations'").fetchone()[0][:800])
print(c.execute("SELECT MIN(t.date_iso), COUNT(*) FROM external_citations e JOIN document_dates t ON t.volume_id=e.volume_id AND t.document_id=e.document_id").fetchone())
print(c.execute("SELECT t.date_iso, e.volume_id, e.document_id FROM external_citations e JOIN document_dates t ON t.volume_id=e.volume_id AND t.document_id=e.document_id ORDER BY t.date_iso LIMIT 3").fetchall())
print("\n== contexts: Q22, Q23 in d105 (which post?), Q9 in d308 (which region?) ==")
def ctx(v,d,needle,before=700,after=100):
    b=c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    i=b.find(needle); print("--",v,d,"offset",i); print(" ".join(b[max(0,i-before):i+len(needle)+after].split())); print()
ctx("frus1969-76v38p2","d105","During this waiting period, programs on U.S. security relations in Asia lack credibility")
ctx("frus1969-76v38p2","d105","hoping that we have all learned the lesson that America is not omnipotent")
ctx("frus1961-63v03","d308","Editorialists are almost unanimously critical",900,100)
ctx("frus1964-68v29p2","d46","52 percent to 38 percent",400,100)
ctx("frus1917-72PubDipv08","d88","only 26 percent",300,200)
ctx("frus1917-72PubDipv06","d127","probably the most successful visit",500,100)
ctx("frus1917-72PubDipv08","d31","One caveat: US visibility should be low",500,100)
ctx("frus1917-72PubDipv08","d149","The predominant mood is apolitical",400,100)
