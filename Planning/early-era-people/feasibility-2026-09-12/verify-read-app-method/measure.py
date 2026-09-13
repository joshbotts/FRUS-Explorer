"""Verifier re-measurement over the three local stores (read-only). Stdlib only.
Adds what grain_sizes.py did not measure: per-volume distinct surfaces (the persons-row count a
surface-keyed artifact would mint), single-token share, same-doc surface collisions on a cleaned
last-token key (COUNT(*) inflation bound), marked-layer link attributes, and document-grain
coverage of the 64-document M2a gold by the editor-marked layer."""
import gzip, json, os, sys, io, collections, re
stores = {
  "marked":           os.path.expanduser("~/frus-ner-raw/marked"),
  "filtered_control": os.path.expanduser("~/frus-ner-raw-control-filtered/detected"),
  "filtered_sweep":   os.path.expanduser("~/frus-ner-raw-filtered/detected"),
}
TITLES = {"mr","mrs","ms","dr","sir","hon","gen","general","col","colonel","capt","captain","lt","lieutenant",
          "maj","major","adm","admiral","rev","prof","lord","count","baron","president","secretary","minister"}
def clean(tok): return re.sub(r"[^a-z0-9]", "", tok.lower())
def lastkey(surface):
    toks = [clean(t) for t in surface.split()]
    toks = [t for t in toks if t and t not in TITLES]
    return toks[-1] if toks else clean(surface)
gold_docs = {}
for line in open("/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a/m2a-ground-truth-documents.jsonl"):
    r = json.loads(line); gold_docs[(r["v"], r["d"])] = r
out = {"gold_documents": len(gold_docs), "gold_documents_with_mentions": sum(1 for r in gold_docs.values() if r["mentions"]>0)}
for label, d in stores.items():
    rows = 0; vols = 0; docs = set(); per_vol_surfaces = 0; single_tok = 0
    doc_surfaces = collections.defaultdict(set); doc_lastkeys = collections.defaultdict(set)
    c_nonnull = 0; t_counts = collections.Counter(); gold_hit = set()
    for fn in sorted(os.listdir(d)):
        if not (fn.endswith(".jsonl") or fn.endswith(".jsonl.gz")): continue
        vol = fn.split(".")[0]; vols += 1; vsurf = set()
        opener = gzip.open if fn.endswith(".gz") else open
        with opener(os.path.join(d, fn), "rt", encoding="utf-8") as fh:
            for line in fh:
                r = json.loads(line); rows += 1
                n = " ".join(r["n"].split()).lower()
                vsurf.add(n); docs.add((vol, r["d"]))
                doc_surfaces[(vol, r["d"])].add(n); doc_lastkeys[(vol, r["d"])].add(lastkey(r["n"]))
                if len(r["n"].split()) == 1: single_tok += 1
                if label == "marked":
                    if r.get("c"): c_nonnull += 1
                    t_counts[r.get("t")] += 1
                if (vol, r["d"]) in gold_docs: gold_hit.add((vol, r["d"]))
        per_vol_surfaces += len(vsurf)
    collide_docs = sum(1 for k in doc_surfaces if len(doc_surfaces[k]) > len(doc_lastkeys[k]))
    surplus_rows = sum(len(doc_surfaces[k]) - len(doc_lastkeys[k]) for k in doc_surfaces)
    pairs = sum(len(v) for v in doc_surfaces.values())
    res = {"volumes": vols, "rows": rows, "documents_with_a_mention": len(docs),
           "pairs_presence_grain": pairs,
           "persons_rows_if_keyed_per_volume_surface": per_vol_surfaces,
           "single_token_rows": single_tok, "single_token_share": round(single_tok/rows, 4),
           "docs_with_surface_collision_on_cleaned_last_token": collide_docs,
           "presence_rows_in_excess_of_last_token_keys": surplus_rows,
           "presence_rows_excess_share": round(surplus_rows/pairs, 4),
           "gold_docs_with_at_least_one_row": len(gold_hit),
           "gold_docs_with_mentions_and_at_least_one_row": sum(1 for k in gold_hit if gold_docs[k]["mentions"]>0)}
    if label == "marked":
        res["rows_with_c_link_attribute"] = c_nonnull; res["rows_by_t"] = dict(t_counts)
    out[label] = res
    print(label, res, file=sys.stderr)
json.dump(out, open(sys.argv[1], "w"), indent=1)
