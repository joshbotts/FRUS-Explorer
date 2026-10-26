# Verify every quotation against document_cache.body_text retrieved in this session:
# (1) exact substring of the raw body_text; (2) substring after whitespace-collapse; plus the on-disk raw file.
import json, sqlite3
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL = "SELECT body_text, length(body_text) FROM document_cache WHERE volume_id = ? AND document_id = ?"
open("out/sql_trace.log", "a").write(f"[verify_quotes.py] {SQL}  -- once per quoted pair\n")
qs = json.load(open("quotes/quotes.json")); out = []
for q in qs:
    v, d = q["pair"].split("/")
    body, blen = con.execute(SQL, (v, d)).fetchone()
    raw_ok = q["text"] in body
    col_ok = " ".join(q["text"].split()) in " ".join(body.split())
    disk = open(f"raw/{v}__{d}.txt").read()
    disk_ok = q["text"] in disk
    pos = body.find(q["text"])
    out.append({**q, "raw_substring": raw_ok, "collapsed_substring": col_ok, "on_disk_raw_file": disk_ok, "offset": pos, "body_chars": blen, "quote_chars": len(q["text"])})
    print(f"{q['id']:5s} {q['pair']:24s} raw={raw_ok} collapsed={col_ok} disk={disk_ok} offset={pos} len={len(q['text'])}")
json.dump(out, open("quotes/quotes_verified.json", "w"), indent=1, ensure_ascii=False)
print("ALL RAW OK:", all(o["raw_substring"] for o in out), "| n =", len(out))
