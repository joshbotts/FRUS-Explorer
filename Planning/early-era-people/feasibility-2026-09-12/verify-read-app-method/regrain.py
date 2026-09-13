"""Independent re-measure: rows, docs, presence pairs, distinct (volume,surface) pairs -- the persons-row analogue -- and gz ratios."""
import gzip, json, os, sys, collections
stores = {"marked": "~/frus-ner-raw/marked", "filtered_sweep": "~/frus-ner-raw-filtered/detected", "filtered_control": "~/frus-ner-raw-control-filtered/detected"}
out = {}
for label, d in stores.items():
    d = os.path.expanduser(d); rows=0; docs=set(); pairs=set(); volsurf=set(); vols=0; corpus_surf=set()
    for fn in sorted(os.listdir(d)):
        if not (fn.endswith(".jsonl") or fn.endswith(".jsonl.gz")): continue
        vol = fn.split(".")[0]; vols += 1
        op = gzip.open if fn.endswith(".gz") else open
        with op(os.path.join(d, fn), "rt", encoding="utf-8") as fh:
            for line in fh:
                r = json.loads(line); rows += 1
                n = " ".join(r["n"].split()).lower()
                docs.add((vol, r["d"])); pairs.add((vol, r["d"], n)); volsurf.add((vol, n)); corpus_surf.add(n)
    out[label] = dict(volumes=vols, rows=rows, docs=len(docs), presence_pairs=len(pairs), volume_surface_pairs=len(volsurf), corpus_surfaces=len(corpus_surf))
    print(label, out[label], file=sys.stderr)
json.dump(out, open(sys.argv[1], "w"), indent=1)
