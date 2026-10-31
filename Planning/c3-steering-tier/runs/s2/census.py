# census (whole hit set, all under 300) of phrase matches: STRICT vs TOLERANT literal share; Python re with re.I
import sqlite3, re
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
HITS = ("SELECT c.volume_id, c.document_id, c.header||' '||COALESCE(c.dateline,'')||' '||COALESCE(c.source_note,'')||' '||c.body_text "
        "FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 "
        "AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') ORDER BY c.volume_id, c.document_id")
print("SQL:", HITS)
fams = [('"questionable payments"', r"questionable payments", r"questionabl\w*[\s\-,().]+payments?"),
        ('"foreign corrupt practices"', r"foreign corrupt practices", r"foreign[\s\-,().]+corrupt\w*[\s\-,().]+practices?"),
        ('"illicit payments"', r"illicit payments", r"illicit\w*[\s\-,().]+payments?"),
        ('"corrupt practices"', r"corrupt practices", r"corrupt\w*[\s\-,().]+practices?")]
for m, s, t in fams:
    rows = con.execute(HITS, (m,)).fetchall()
    S = re.compile(r"\b"+s+r"\b", re.I); T = re.compile(r"\b"+t+r"\b", re.I)
    ns = nt = 0; miss=[]
    for v, d, txt in rows:
        txt = re.sub(r"\s+", " ", txt)
        a = bool(S.search(txt)); b = bool(T.search(txt)); ns += a; nt += b
        if not b: miss.append("%s/%s" % (v, d))
    print("MATCH %s: N=%d (census)  STRICT %d of %d  TOLERANT %d of %d  | tolerant misses: %s" % (m, len(rows), ns, len(rows), nt, len(rows), miss))
    print("   STRICT re:", S.pattern, " TOLERANT re:", T.pattern)
    if m=='"illicit payments"' or m=='"foreign corrupt practices"': print("   hits:", ["%s/%s"%(v,d) for v,d,_ in rows])
r = con.execute("SELECT c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt OR bribe OR briberi OR graft OR kickback OR embezzl' AND c.volume_id='frus1977-80v09Ed2' AND c.is_front_matter=0 AND c.is_editorial_note=0").fetchall()
print("family hits in frus1977-80v09Ed2:", r)
