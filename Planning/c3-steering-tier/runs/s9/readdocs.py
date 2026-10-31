import sqlite3, re, sys, os
# usage: readdocs.py REGEX vol/doc [vol/doc ...]  -- dumps whole doc to raw/, prints contexts
R="/Users/jbotts/frus-analysis/c3s/runs/s9"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rx = re.compile(sys.argv[1], re.I)
W = int(os.environ.get("W","300")); K=int(os.environ.get("K","4"))
for p in sys.argv[2:]:
    v, d = p.split("/")
    row = con.execute("SELECT c.header, IFNULL(c.dateline,''), IFNULL(c.source_note,''), c.body_text, length(c.body_text), dd.date_iso FROM document_cache c LEFT JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?", (v, d)).fetchone()
    if not row: print("MISSING", p); continue
    h, dl, sn, b, L, dt = row
    with open(f"{R}/raw/{v}__{d}.txt", "w") as f:
        f.write(f"HEADER: {h}\nDATELINE: {dl}\nSOURCE: {sn}\nDATE: {dt}\nLEN(body_text chars): {L}\n\n{b}")
    t = re.sub(r"\s+", " ", b)
    print(f"\n#### {p} | {dt} | len={L} | {re.sub(chr(10),' ',h)[:150]}\nSRC: {sn[:300]}")
    for i, m in enumerate(rx.finditer(t)):
        if i >= K: break
        print(f"  ...{t[max(0,m.start()-W):m.end()+W]}...")
