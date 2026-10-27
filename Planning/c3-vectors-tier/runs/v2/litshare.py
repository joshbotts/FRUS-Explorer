# Literal share for the FTS family {header body_text}: (cuba OR cuban OR havana), apparatus excluded, Ed2 dropped.
# Hit list sorted by (volume_id, document_id); evenly spaced sample of 40. Surface: header+dateline+source_note+body_text, whitespace-collapsed.
# STRICT: \b(cuba|cuban|havana)\b (re.I).  TOLERANT: \b(cuba|cubans?|havana|havannah?)('s)?\b (re.I).
import sqlite3, re
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL = """SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
WHERE frus_documents MATCH '{header body_text}: (cuba OR cuban OR havana)' AND c.is_front_matter=0 AND c.is_editorial_note=0
AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') ORDER BY c.volume_id, c.document_id"""
hits = db.execute(SQL).fetchall()
M = len(hits); step = M / 40; sample = [hits[int(i * step)] for i in range(40)]
S = re.compile(r"\b(cuba|cuban|havana)\b", re.I); T = re.compile(r"\b(cuba|cubans?|havana|havannah?)('s)?\b", re.I)
s = t = 0; miss = []
for v, d in sample:
    r = db.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    x = " ".join(" ".join(z or "" for z in r).split())
    a, b = bool(S.search(x)), bool(T.search(x)); s += a; t += b
    if not b: miss.append(f"{v}/{d}")
print("hit list M =", M); print("TOLERANT", t, "of 40; STRICT", s, "of 40"); print("tolerant misses:", miss)
