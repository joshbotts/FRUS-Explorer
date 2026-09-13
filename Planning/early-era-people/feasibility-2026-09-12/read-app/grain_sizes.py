"""Measure, per detector store, the size of an OFFSET-grain artifact vs a DOCUMENT-PRESENCE-grain one.
Presence grain = one row per (volume, doc, normalised surface); offsets grain = the store's own rows.
Stdlib only; read-only over the stores."""
import gzip, json, os, sys, io, collections
stores = {
  "marked":            os.path.expanduser("~/frus-ner-raw/marked"),
  "filtered_sweep":    os.path.expanduser("~/frus-ner-raw-filtered/detected"),
  "filtered_control":  os.path.expanduser("~/frus-ner-raw-control-filtered/detected"),
}
out = {}
for label, d in stores.items():
    rows = 0; docs = set(); pairs = set(); vols = 0
    surfaces = collections.Counter()
    offs_json = io.BytesIO(); pres_json = io.BytesIO()
    for fn in sorted(os.listdir(d)):
        if not (fn.endswith(".jsonl") or fn.endswith(".jsonl.gz")): continue
        vol = fn.split(".")[0]; vols += 1
        opener = gzip.open if fn.endswith(".gz") else open
        with opener(os.path.join(d, fn), "rt", encoding="utf-8") as fh:
            for line in fh:
                r = json.loads(line); rows += 1
                docs.add((vol, r["d"]))
                key = (vol, r["d"], " ".join(r["n"].split()).lower())
                if key not in pairs:
                    pairs.add(key)
                    pres_json.write(json.dumps({"v":vol,"d":r["d"],"n":r["n"]}, ensure_ascii=False).encode()+b"\n")
                offs_json.write(json.dumps({"v":vol,"d":r["d"],"s":r["s"],"e":r["e"],"n":r["n"]}, ensure_ascii=False).encode()+b"\n")
                surfaces[key[2]] += 1
    def gz(b): return len(gzip.compress(b, 9))
    out[label] = {
        "volumes": vols, "rows_offsets_grain": rows, "documents_with_a_mention": len(docs),
        "pairs_presence_grain": len(pairs), "distinct_normalised_surfaces": len(surfaces),
        "offsets_jsonl_bytes": offs_json.tell(), "offsets_jsonl_gz_bytes": gz(offs_json.getvalue()),
        "presence_jsonl_bytes": pres_json.tell(), "presence_jsonl_gz_bytes": gz(pres_json.getvalue()),
    }
    print(label, out[label], file=sys.stderr)
json.dump(out, open(sys.argv[1], "w"), indent=1)
