import sqlite3, re, sys, json
# share.py LABEL MATCH STRICT TOLERANT  -> census if M<300 else evenly spaced sample of 40. Python re, re.I.
lab, m, sx, tx = sys.argv[1:5]
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
ids = con.execute("SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') ORDER BY c.volume_id, c.document_id", (m,)).fetchall()
M = len(ids)
if M < 300: pick = ids; mode = "census"
else:
    step = M / 40; pick = [ids[int(i*step)] for i in range(40)]; mode = "sample40"
S = re.compile(sx, re.I); T = re.compile(tx, re.I)
s = t = 0; miss = []
for v, d in pick:
    h, dl, sn, b = con.execute("SELECT header, IFNULL(dateline,''), IFNULL(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    txt = re.sub(r"\s+", " ", " ".join([h, dl, sn, b]))
    a = bool(S.search(txt)); bb = bool(T.search(txt)); s += a; t += bb
    if not bb: miss.append(f"{v}/{d}")
res = {"label": lab, "match": m, "strict": sx, "tolerant": tx, "M_hitlist_excl_fm_ed_Ed2": M, "mode": mode, "n": len(pick), "strict_hits": s, "tolerant_hits": t, "tolerant_misses": miss}
json.dump(res, open(f"/Users/jbotts/frus-analysis/c3s/runs/s9/share_{lab}.json", "w"), indent=1)
print(f"{lab}: M={M} {mode} n={len(pick)} STRICT {s} of {len(pick)} | TOLERANT {t} of {len(pick)} | misses {miss[:8]}")
