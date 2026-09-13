"""Independent re-derivation of RA-10 (grain sizes). Different mechanism from the author's
grain_sizes.py: dedup + counting via an in-memory SQLite table (not Python sets), rows counted
from raw line splits, sizes computed BOTH in the author's field layout (json.dumps default
separators — needed for byte comparability) and in a compact layout (context)."""
import gzip, json, os, sqlite3, sys, io, hashlib
stores = {
  "marked":           os.path.expanduser("~/frus-ner-raw/marked"),
  "filtered_sweep":   os.path.expanduser("~/frus-ner-raw-filtered/detected"),
  "filtered_control": os.path.expanduser("~/frus-ner-raw-control-filtered/detected"),
}
out = {}
for label, d in stores.items():
    db = sqlite3.connect(":memory:")
    db.execute("CREATE TABLE m (v TEXT, d TEXT, s INT, e INT, n TEXT, k TEXT)")
    files = sorted(f for f in os.listdir(d) if f.endswith(".jsonl.gz") or f.endswith(".jsonl"))
    vols = set(); nlines = 0
    for fn in files:
        vol = fn.split(".")[0]; vols.add(vol)
        raw = gzip.open(os.path.join(d, fn), "rb").read() if fn.endswith(".gz") else open(os.path.join(d, fn), "rb").read()
        lines = raw.decode("utf-8").split("\n")
        batch = []
        for ln in lines:
            if not ln.strip(): continue
            nlines += 1
            r = json.loads(ln)
            batch.append((vol, r["d"], r["s"], r["e"], r["n"], " ".join(r["n"].split()).lower()))
        db.executemany("INSERT INTO m VALUES (?,?,?,?,?,?)", batch)
    rows = db.execute("SELECT COUNT(*) FROM m").fetchone()[0]
    docs = db.execute("SELECT COUNT(*) FROM (SELECT DISTINCT v, d FROM m)").fetchone()[0]
    pairs = db.execute("SELECT COUNT(*) FROM (SELECT DISTINCT v, d, k FROM m)").fetchone()[0]
    surfaces = db.execute("SELECT COUNT(DISTINCT k) FROM m").fetchone()[0]
    # sizes, author layout (default separators) and compact layout
    offs = io.BytesIO(); pres = io.BytesIO(); offs_c = io.BytesIO(); pres_c = io.BytesIO()
    for v, dd, s, e, n in db.execute("SELECT v, d, s, e, n FROM m ORDER BY rowid"):
        offs.write(json.dumps({"v":v,"d":dd,"s":s,"e":e,"n":n}, ensure_ascii=False).encode()+b"\n")
        offs_c.write(json.dumps({"v":v,"d":dd,"s":s,"e":e,"n":n}, ensure_ascii=False, separators=(",",":")).encode()+b"\n")
    # presence: first occurrence per (v,d,k), keeping the FIRST surface spelling, in row order
    for v, dd, n in db.execute("SELECT v, d, n FROM m WHERE rowid IN (SELECT MIN(rowid) FROM m GROUP BY v, d, k) ORDER BY rowid"):
        pres.write(json.dumps({"v":v,"d":dd,"n":n}, ensure_ascii=False).encode()+b"\n")
        pres_c.write(json.dumps({"v":v,"d":dd,"n":n}, ensure_ascii=False, separators=(",",":")).encode()+b"\n")
    gz = lambda b: len(gzip.compress(b.getvalue(), 9))
    out[label] = dict(volumes=len(vols), lines=nlines, rows=rows, docs=docs, pairs=pairs, surfaces=surfaces,
        offsets_bytes=offs.tell(), offsets_gz=gz(offs), presence_bytes=pres.tell(), presence_gz=gz(pres),
        offsets_compact_bytes=offs_c.tell(), offsets_compact_gz=gz(offs_c),
        presence_compact_bytes=pres_c.tell(), presence_compact_gz=gz(pres_c),
        ratio_offsets_over_presence_gz=round(gz(offs)/gz(pres), 3),
        ratio_offsets_over_presence_raw=round(offs.tell()/pres.tell(), 3))
    print(label, out[label], file=sys.stderr, flush=True)
    db.close()
json.dump(out, open(sys.argv[1], "w"), indent=1)
