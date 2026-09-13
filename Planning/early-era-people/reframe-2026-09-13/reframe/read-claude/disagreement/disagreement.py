#!/usr/bin/env python3
"""Role 2 sizing (read-only, stdlib): the corpus-scale DISAGREEMENT set between the filtered NLTagger store (FC)
and the filtered qwen3-14b sweep store (FS) over the 267-volume TEI-rule scope, and the post-hoc gold-sample
ceiling of verifying ONLY that set on top of the assessment's agreement arm (editor U (FS spans overlapping FC)).

Definitions (same overlap rule as measure-grains/grains.py: >0 chars shared, same document):
  agree_S   FS spans overlapping >=1 FC span (the assessment's intersection, sweep side)
  S_only    FS spans overlapping no FC span
  C_only    FC spans overlapping no FS span
  unmarked  a span overlapping no editor <persName> span (editor-covered spans need no verification)
  disagreement set = (S_only U C_only) restricted to unmarked
Unit counts: spans, distinct (document, surface_key) pairs (grains.surface_key), documents touched, and the
characters of +/-WIN windows merged per document (clipped to the document length from llm-pass docs.tsv).
Writes disagreement.json beside this file."""
import os, sys, json, collections, bisect, time
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, REPO + "/tools/semantic-harvest")
sys.path.insert(0, REPO + "/Planning/early-era-people/feasibility-2026-09-12/measure-grains")
import grains as G          # sets the scorer env before importing score_detections; main() is guarded
import ner_store as st
sd = G.sd
H = os.path.expanduser("~")
E_ST, FC_ST, FS_ST = (H + "/frus-ner-raw", "marked"), (H + "/frus-ner-raw-control-filtered", "detected"), (H + "/frus-ner-raw-filtered", "detected")
DOCS_TSV = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/llm-pass/cost-scale/docs.tsv"
WIN = int(os.environ.get("WIN", "200"))

def index(spans):
    spans = sorted(spans)
    starts = [s for s, _, _ in spans]
    mx, m = [], -1
    for _, e, _ in spans:
        m = max(m, e); mx.append(m)
    return starts, mx

def hits(span, idx):
    starts, mx = idx
    i = bisect.bisect_left(starts, span[1])
    return i > 0 and mx[i - 1] > span[0]

def merged_chars(spans, doclen):
    iv = sorted((max(0, s - WIN), min(doclen, e + WIN)) for s, e, _ in spans)
    tot, cs, ce = 0, None, None
    for a, b in iv:
        if cs is None: cs, ce = a, b
        elif a <= ce: ce = max(ce, b)
        else: tot += ce - cs; cs, ce = a, b
    if cs is not None: tot += ce - cs
    return tot

def classify(E, C, S):
    ei, ci, si = index(E), index(C), index(S)
    agree_S = [x for x in S if hits(x, ci)]
    S_only = [x for x in S if not hits(x, ci)]
    C_only = [x for x in C if not hits(x, si)]
    um = lambda xs: [x for x in xs if not hits(x, ei)]
    return {"agree_S": um(agree_S), "S_only": um(S_only), "C_only": um(C_only),
            "pool": um(sorted(set(C) | set(S)))}

def main():
    t0 = time.time()
    doclen = {}
    with open(DOCS_TSV) as f:
        next(f)
        for line in f:
            p = line.split("\t"); doclen[(p[0], p[1])] = int(p[2])
    vols = st.scope_volumes(E_ST[0])
    SETS = ("agree_S", "S_only", "C_only", "disagreement", "pool")
    tot = {b: {k: collections.Counter() for k in SETS} for b in ("all",) + tuple(x[2] for x in st.BANDS)}
    for n, v in enumerate(vols):
        band = st.band_of(v)
        e = st.spans_by_document(st.volume_layer(E_ST[0], E_ST[1], v))
        c = st.spans_by_document(st.volume_layer(FC_ST[0], FC_ST[1], v))
        s = st.spans_by_document(st.volume_layer(FS_ST[0], FS_ST[1], v))
        for d in set(e) | set(c) | set(s):
            r = classify(e.get(d, []), c.get(d, []), s.get(d, []))
            r["disagreement"] = sorted(set(r["S_only"]) | set(r["C_only"]))
            L = doclen.get((v, d))
            for k in SETS:
                xs = r[k]
                if not xs: continue
                keys = {G.surface_key(x[2]) for x in xs}
                first = {}
                for x in xs:
                    first.setdefault(G.surface_key(x[2]), x)
                for b in ("all", band):
                    T = tot[b][k]
                    T["spans"] += len(xs); T["doc_surface_keys"] += len(keys); T["documents"] += 1
                    T["surface_chars"] += sum(len(x[2]) for x in xs)
                    if L is not None:
                        T["window_chars_all_spans"] += merged_chars(xs, L)
                        T["window_chars_first_per_key"] += merged_chars(list(first.values()), L)
                    else:
                        T["docs_without_length"] += 1
        if n % 50 == 0: print("[%d/%d] %s %.0fs" % (n + 1, len(vols), v, time.time() - t0), file=sys.stderr)
    out = {"method": __doc__, "window_half_width_chars": WIN, "volumes": len(vols), "documents_in_docs_tsv": len(doclen),
           "corpus": {b: {k: dict(v) for k, v in d.items()} for b, d in tot.items()}, "seconds": round(time.time() - t0, 1)}
    # ---------------- gold sample (POST-HOC, n = 64 documents / 406 mentions)
    gold, bands = sd.load_ground_truth(os.environ["GROUND_TRUTH"])
    arms = {}
    for name, (p, layer) in (("editor", E_ST), ("filtered_control", FC_ST), ("filtered_sweep", FS_ST)):
        preds, refused = sd.collect_predictions(p, layer, gold, True)
        assert not refused and set(preds) == set(gold), name
        arms[name] = preds
    E, FC, FS = arms["editor"], arms["filtered_control"], arms["filtered_sweep"]
    agree = G.intersection(FS, FC)
    base = G.union_exact(E, agree)
    dis, pool = {}, {}
    for k in gold:
        r = classify(E[k], FC[k], FS[k])
        dis[k] = sorted(set(r["S_only"]) | set(r["C_only"]))
        pool[k] = r["pool"]
    def summarize(preds):
        counts, fk, mk, tk, _, _ = G.presence_doc_counts(gold, preds)
        res = {}
        for b in ("all",) + tuple(sorted(set(bands.values()))):
            ks = [k for k in counts if b == "all" or bands[k] == b]
            ph = sum(counts[k][0] for k in ks); pk = sum(counts[k][1] for k in ks)
            gh = sum(counts[k][2] for k in ks); gk = sum(counts[k][3] for k in ks)
            P = ph / pk if pk else 0.0; R = gh / gk if gk else 0.0
            res[b] = {"pred_keys": pk, "false_keys": pk - ph, "gold_keys": gk, "found": gh,
                      "P": round(P, 4), "R": round(R, 4), "F1": round(2 * P * R / (P + R), 4) if P + R else 0.0}
        return res
    def perfect_add(base_preds, extra):
        """Keep only `extra` spans that match gold mentions left unmatched by `base_preds` (a perfect verifier)."""
        kept = {}
        n_extra = n_kept = 0
        for k in gold:
            gs = gold[k]
            _, _, _, used_gold = sd.match(gs, base_preds.get(k, []))
            remaining = [g for i, g in enumerate(gs) if i not in used_gold]
            ex = extra.get(k, [])
            n_extra += len(ex)
            _, _, used_pred, _ = sd.match(remaining, ex)
            keep = [x for i, x in enumerate(ex) if i in used_pred]
            n_kept += len(keep)
            kept[k] = sorted(set(base_preds.get(k, [])) | set(keep))
        return kept, n_extra, n_kept
    plus_dis, nd, nk = perfect_add(base, dis)
    true_agree = {}
    for k in gold:
        _, _, used_pred, _ = sd.match(gold[k], agree[k])
        true_agree[k] = [x for i, x in enumerate(agree[k]) if i in used_pred]
    filtered_base = G.union_exact(E, true_agree)
    both, _, _ = perfect_add(filtered_base, dis)
    out["gold"] = {
        "label": "POST-HOC ceilings on the M2a gold (64 docs / 406 mentions / presence grain as grains.py). A ceiling is not a precision.",
        "editor_U_agreement_arm (baseline, assessment b2)": summarize(base),
        "disagreement_spans_on_gold_docs": nd, "disagreement_spans_a_perfect_verifier_keeps": nk,
        "baseline_plus_perfectly_verified_disagreement": summarize(plus_dis),
        "editor_U_perfectly_filtered_agreement": summarize(filtered_base),
        "editor_U_perfectly_filtered_agreement_plus_perfectly_verified_disagreement": summarize(both),
        "editor_U_filtered_control_U_filtered_sweep_unverified": summarize(G.union_exact(E, FC, FS)),
    }
    json.dump(out, open(os.path.join(HERE, "disagreement.json"), "w"), indent=1)
    print(json.dumps(out["corpus"]["all"], indent=1)); print(json.dumps(out["gold"], indent=1))

if __name__ == "__main__":
    main()
