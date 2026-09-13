#!/usr/bin/env python3
"""Stores-only follow-up (uses v_census.py's own reader/overlap/K2): identity-proxy collapse of the names the
arm adds (last token), concentration of the arm's distinct rows, corpus-singleton share of added pairs,
single-token share, top net keys per pool. Writes v-light.json."""
import collections, json, os, statistics, sys, time
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import v_census as vc
t0 = time.time()
scope = json.load(open(vc.HOME + "/frus-ner-raw/scope.json"))["volumes"]
B = vc.BANDS
C = collections.Counter()
rowkey = collections.Counter()
addedkey = collections.Counter()
netkey = {p: collections.Counter() for p in ("fs_only", "fc_only")}
new_last_per_gain_doc = []
for vol in scope:
    band = vc.band_of(vol)
    byd = {}
    for nm, dp in (("E", vc.E_DIR), ("FC", vc.FC_DIR), ("FS", vc.FS_DIR)):
        g = collections.defaultdict(set)
        for r in vc.read_jsonl(dp, vol):
            g[r["d"]].add((r["s"], r["e"], r["n"]))
        byd[nm] = g
    for d in set(byd["E"]) | set(byd["FC"]) | set(byd["FS"]):
        e, fc, fs = byd["E"].get(d, set()), byd["FC"].get(d, set()), byd["FS"].get(d, set())
        cfc, cfs = vc.coverage(fc), vc.coverage(fs)
        int_fs = {x for x in fs if vc.touches(x[0], x[1], cfc)}
        fs_only = fs - int_fs
        fc_only = {x for x in fc if not vc.touches(x[0], x[1], cfs)}
        agr = e | int_fs
        for x in agr:
            rowkey[vc.K(x[2])] += 1
        kE = {vc.K(x[2]) for x in e}
        kA = {vc.K(x[2]) for x in agr}
        added = kA - kE
        for k in added:
            addedkey[k] += 1
        for pn, pr in (("fs_only", fs_only), ("fc_only", fc_only)):
            for k in {vc.K(x[2]) for x in pr} - kA:
                netkey[pn][k] += 1
        last = lambda ks: {k.split()[-1] for k in ks if k.split()}
        eL, aL = last(kE), last(kA)
        newL = last(added) - eL
        for b in (band, "all"):
            C[("arm_pairs", b)] += len(kA)
            C[("arm_pairs_lasttoken_collapsed", b)] += len(aL)
            C[("editor_pairs", b)] += len(kE)
            C[("editor_pairs_lasttoken_collapsed", b)] += len(eL)
            C[("added_pairs", b)] += len(added)
            C[("added_new_last_tokens", b)] += len(newL)
            C[("docs_gaining", b)] += 1 if added else 0
            C[("docs_gaining_new_last_token", b)] += 1 if newL else 0
        if newL:
            new_last_per_gain_doc.append(len(newL))
rows_total = sum(rowkey.values())
ap_total = sum(addedkey.values())
single_tok_added = sum(n for k, n in addedkey.items() if len(k.split()) == 1)
out = {"script": os.path.abspath(__file__),
       "collapse": {m: {b: C[(m, b)] for b in B + ["all"]} for m in ("arm_pairs", "arm_pairs_lasttoken_collapsed", "editor_pairs", "editor_pairs_lasttoken_collapsed", "added_pairs", "added_new_last_tokens", "docs_gaining", "docs_gaining_new_last_token")},
       "new_last_tokens_per_doc_gaining_one": {"mean": round(sum(new_last_per_gain_doc) / len(new_last_per_gain_doc), 3), "median": statistics.median(new_last_per_gain_doc)},
       "concentration_distinct_rows": {"rows": rows_total, "keys": len(rowkey),
                                       "share_rows_on_singleton_keys": round(sum(n for n in rowkey.values() if n == 1) / rows_total, 4),
                                       "keys_ge5": sum(1 for n in rowkey.values() if n >= 5), "share_rows_on_keys_ge5": round(sum(n for n in rowkey.values() if n >= 5) / rows_total, 4)},
       "added_pairs": ap_total, "share_added_pairs_on_corpus_singleton_keys": round(sum(n for n in addedkey.values() if n == 1) / ap_total, 4),
       "added_single_token_pairs": single_tok_added, "share_added_single_token": round(single_tok_added / ap_total, 4),
       "top_added": addedkey.most_common(15), "top_net": {p: c.most_common(10) for p, c in netkey.items()},
       "elapsed": round(time.time() - t0, 1)}
json.dump(out, open(os.path.join(HERE, "v-light.json"), "w"), indent=1, ensure_ascii=False)
print(json.dumps(out, indent=1, ensure_ascii=False))
