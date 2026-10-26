# Usage: python3 -I scripts/read_docs.py vol/doc [vol/doc ...]  [--max N]
# Retrieves header, dateline, source_note, body_text for each (volume_id, document_id) -- never summary_text or note_text --
# writes the raw text to raw/<vol>__<doc>.txt, logs the SELECT to out/sql_trace.log, records captured length vs
# length(body_text) in out/reading_log.tsv, and prints the text (up to --max characters of body).
import sqlite3, sys, os
args = [a for a in sys.argv[1:] if not a.startswith("--")]
mx = 100000
if "--max" in sys.argv: mx = int(sys.argv[sys.argv.index("--max") + 1]); args = [a for a in args if a != str(mx)]
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL = """SELECT c.volume_id, c.document_id, c.document_number, c.header, c.dateline, c.source_note, c.body_text,
         length(c.body_text), c.is_front_matter, c.is_editorial_note, d.date_iso
         FROM document_cache c LEFT JOIN document_dates d ON d.volume_id = c.volume_id AND d.document_id = c.document_id
         WHERE c.volume_id = ? AND c.document_id = ?"""
tr = open("out/sql_trace.log", "a"); lg = open("out/reading_log.tsv", "a")
for a in args:
    v, d = a.split("/")
    tr.write(f"[read_docs.py] {' '.join(SQL.split())}  -- args=({v!r}, {d!r})\n")
    r = con.execute(SQL, (v, d)).fetchone()
    if not r: print(f"#### {a}: NOT FOUND"); continue
    _, _, num, h, dl, sn, body, blen, fm, en, dt = r
    path = f"raw/{v}__{d}.txt"
    with open(path, "w") as f:
        f.write(f"VOLUME_ID: {v}\nDOCUMENT_ID: {d}\nDOCUMENT_NUMBER: {num}\nDATE_ISO: {dt}\nFRONT_MATTER: {fm} EDITORIAL_NOTE: {en}\nHEADER: {h}\nDATELINE: {dl}\nSOURCE_NOTE: {sn}\nBODY_LENGTH_CHARS: {blen}\n=== BODY ===\n{body}\n")
    lg.write(f"{v}\t{d}\t{blen}\t{len(body)}\t{'whole' if len(body) == blen else 'partial'}\n")
    print(f"#### {v}/{d}  date={dt}  num={num}  body_chars={blen} captured={len(body)}  fm={fm} en={en}")
    print("HEADER:", " ".join((h or "").split()))
    print("DATELINE:", " ".join((dl or "").split()))
    print("SOURCE:", " ".join((sn or "").split())[:400])
    b = " ".join(body.split())
    print("BODY:", b[:mx] + (" [...display truncated; full text on disk]" if len(b) > mx else ""))
    print()
