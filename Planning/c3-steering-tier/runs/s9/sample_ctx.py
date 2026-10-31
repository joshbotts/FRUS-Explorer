import sqlite3, re, sys, json
# usage: sample_ctx.py MATCHEXPR REGEX N OUTFILE
m, rx, N, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
sql = ("SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid "
       "WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 ORDER BY c.volume_id, c.document_id")
ids = con.execute(sql, (m,)).fetchall()
M = len(ids)
step = M / N if M > N else 1
pick = [ids[int(i*step)] for i in range(min(N, M))]
r = re.compile(rx, re.I)
hits = 0; rows = []
for v, d in pick:
    h, dl, sn, b = con.execute("SELECT header, IFNULL(dateline,''), IFNULL(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    t = re.sub(r"\s+", " ", " ".join([h, dl, sn, b]))
    mm = r.search(t)
    if mm: hits += 1
    ctx = t[max(0, mm.start()-150): mm.end()+150] if mm else ""
    rows.append({"v": v, "d": d, "hit": bool(mm), "ctx": ctx})
json.dump({"match": m, "regex": rx, "M": M, "n": len(pick), "hits": hits, "rows": rows}, open(out, "w"), indent=1)
print(m, "| regex", rx, "| hitlist M =", M, "| sample", len(pick), "| literal hits", hits)
