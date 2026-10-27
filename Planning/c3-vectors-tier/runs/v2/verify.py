# Verify every quotation: exact substring of body_text (raw), and of the whitespace-collapsed header+dateline+source_note+body_text.
# SELECT body_text, header, dateline, source_note, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?
import sqlite3, json
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
ok = 0; Q = json.load(open("quotes.json"))
for v, d, q in Q:
    r = db.execute("SELECT body_text, header, dateline, source_note, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    raw = q in r[0]; col = " ".join(q.split()) in " ".join(" ".join([r[1] or "", r[2] or "", r[3] or "", r[0]]).split())
    ok += raw and col
    print(f"{v}/{d}\tlen={r[4]}\tfm={r[5]} en={r[6]}\traw={raw}\tcollapsed={col}\t{q[:60]}")
print("verified", ok, "of", len(Q), "quotations;", len(set((v, d) for v, d, q in Q)), "documents")
