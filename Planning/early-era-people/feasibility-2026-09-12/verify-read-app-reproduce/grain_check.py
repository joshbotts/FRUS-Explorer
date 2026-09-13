"""Independent re-derivation of RA-10's grain figures.
Differs from the author's grain_sizes.py in: (1) volumes are enumerated from head.json markers, not
from jsonl filenames, (2) rows are read through the repo's own ner_store.read_jsonl_gz, (3) presence
pairs are counted per volume as dict-of-sets and summed, (4) gzip sizes are computed BOTH with
gzip.compress(level=9) and with the /usr/bin/gzip -9 CLI, (5) it also checks the marked layer's
from/to/untyped split and corresp count against NER-RUNBOOK §4 (245,747 / 140,504 / 95,247 / 9,996 / 0).
Stdlib only; read-only."""
import sys, os, json, gzip, collections, subprocess, tempfile
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
import ner_store

STORES = {
    "marked":           os.path.expanduser("~/frus-ner-raw/marked"),
    "filtered_sweep":   os.path.expanduser("~/frus-ner-raw-filtered/detected"),
    "filtered_control": os.path.expanduser("~/frus-ner-raw-control-filtered/detected"),
}
def norm(n): return " ".join(n.split()).lower()
def cli_gz(path):
    r = subprocess.run(["/usr/bin/gzip", "-9", "-c", path], capture_output=True, check=True)
    return len(r.stdout)

result = {}
for label, d in STORES.items():
    vols = sorted(f[:-len(".head.json")] for f in os.listdir(d) if f.endswith(".head.json"))
    rows = 0; docs_per_vol = 0; pairs_total = 0
    surfaces = set(); types = collections.Counter(); corresp = 0
    tmpdir = tempfile.mkdtemp(prefix="grain_"); offs_path = os.path.join(tmpdir, "offsets.jsonl"); pres_path = os.path.join(tmpdir, "presence.jsonl")
    with open(offs_path, "wb") as fo, open(pres_path, "wb") as fp:
        for v in vols:
            path = ner_store.one_jsonl(d, v, label)
            if path is None: raise SystemExit(f"{label}: no jsonl for {v}")
            recs = ner_store.read_jsonl_gz(path)
            rows += len(recs)
            docs = set(); seen = set()
            for r in recs:
                docs.add(r["d"]); key = (r["d"], norm(r["n"])); surfaces.add(key[1])
                if label == "marked":
                    types[r.get("t")] += 1
                    if r.get("c") is not None: corresp += 1
                fo.write(json.dumps({"v": v, "d": r["d"], "s": r["s"], "e": r["e"], "n": r["n"]}, ensure_ascii=False).encode() + b"\n")
                if key not in seen:
                    seen.add(key)
                    fp.write(json.dumps({"v": v, "d": r["d"], "n": r["n"]}, ensure_ascii=False).encode() + b"\n")
            docs_per_vol += len(docs); pairs_total += len(seen)
    o = open(offs_path, "rb").read(); p = open(pres_path, "rb").read()
    result[label] = {
        "volumes": len(vols), "rows": rows, "documents_with_mention": docs_per_vol,
        "presence_pairs": pairs_total, "distinct_normalised_surfaces": len(surfaces),
        "offsets_bytes": len(o), "offsets_gz_pylib9": len(gzip.compress(o, 9)), "offsets_gz_cli9": cli_gz(offs_path),
        "presence_bytes": len(p), "presence_gz_pylib9": len(gzip.compress(p, 9)), "presence_gz_cli9": cli_gz(pres_path),
    }
    if label == "marked":
        result[label]["type_split"] = dict(types); result[label]["rows_with_corresp"] = corresp
    print(label, json.dumps(result[label]), file=sys.stderr, flush=True)
    for f in (offs_path, pres_path): os.remove(f)
    os.rmdir(tmpdir)
json.dump(result, open(sys.argv[1], "w"), indent=1)
