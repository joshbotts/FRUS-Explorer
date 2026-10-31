import sqlite3, re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
def text(v,d):
    r=db.execute("SELECT header, COALESCE(dateline,''), COALESCE(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    return " ".join(" ".join(r).split())
t=text("frus1958-60v01","d135"); m=re.search(r'Capitol Hill', t); print("== d135 around the quotation ==\n", t[max(0,m.start()-700):m.end()+300])
t=text("frus1950v03","d728"); m=re.search(r'personal corruption', t); print("\n== d728 around 'personal corruption' ==\n", t[max(0,m.start()-900):m.end()+400])
for d in ("d6","d7","d8"):
    t=text("frus1964-68v32",d)
    ms=[t[max(0,m.start()-160):m.end()+160] for m in re.finditer(r'Bonilla', t)][:3]
    print(f"\n== frus1964-68v32/{d} Bonilla mentions ({len(re.findall('Bonilla',t))}) ==")
    for s in ms: print("  ...", s, "...")
print("\n== d842 whole text ==\n", text("frus1922v01","d842"))
