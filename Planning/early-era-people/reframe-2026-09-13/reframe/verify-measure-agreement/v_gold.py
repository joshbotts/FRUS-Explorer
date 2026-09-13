#!/usr/bin/env python3
"""verify-measure-agreement: INDEPENDENT re-score of the agreement arm on the M2a gold.

No import of score_detections, grains, agreement or census. Own gold loader, own store reader,
own Kuhn maximum-cardinality matcher (same documented tie-break: gold in index order, candidates by
descending overlap then index), plus a REVERSED tie-break variant to test tie-break sensitivity,
own presence-grain key (grains.py's 74-token repeated-honorific rule, re-typed from its definition),
own census K2 (token-based), own band-stratified bootstrap (seed 234, 10,000 draws).
Writes v-gold.json beside this script. Stdlib only; read-only.
"""
import collections, gzip, json, os, random

HOME = os.path.expanduser("~")
M2A = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a"
DIRS = {"E": HOME + "/frus-ner-raw/marked", "FC": HOME + "/frus-ner-raw-control-filtered/detected",
        "FS": HOME + "/frus-ner-raw-filtered/detected"}
TEXT = HOME + "/frus-semantic-raw/text"
OUT = os.path.dirname(os.path.abspath(__file__))


def read_jsonl(dirpath, vol):
    cands = [p for p in (os.path.join(dirpath, vol + ".jsonl"), os.path.join(dirpath, vol + ".jsonl.gz")) if os.path.exists(p)]
    assert len(cands) == 1, (dirpath, vol, cands)
    op = gzip.open if cands[0].endswith(".gz") else open
    with op(cands[0], "rt", encoding="utf-8") as h:
        return [json.loads(x) for x in h if x.strip()]


G_HON = set("""mr mrs ms miss messrs dr hon sir lord lady general gen colonel col captain capt major maj lieutenant lieut lt
admiral adm commodore commander cmdr president secretary senator ambassador minister consul judge governor gov count
countess baron baroness earl duke prince princess king queen señor senor don monsieur m madame mme herr rev reverend
professor prof the acting vice privy his her excellency chairman marshal premier chancellor bishop archbishop cardinal
father brother sister""".split())
assert len(G_HON) == 74, len(G_HON)


def gkey(n):
    s = " ".join(n.casefold().split())
    for suf in ("'s", "’s", "'", "’"):
        if s.endswith(suf):
            s = s[:-len(suf)]
            break
    s = s.strip()
    t = s.split()
    i = 0
    while i < len(t) and t[i].rstrip(".") in G_HON:
        i += 1
    r = " ".join(t[i:])
    return r if r else s


C_HON = set("mr mrs miss dr sir hon general colonel captain major admiral señor monsieur herr mme messrs rev judge governor president minister count baron lord lady prince king queen".split())
assert len(C_HON) == 28


def k2(n):
    s = " ".join(n.casefold().split())
    for suf in ("’s", "'s", "’", "'"):
        if s.endswith(suf):
            s = s[:-len(suf)]
            break
    s = s.strip()
    p = s.split(" ", 1)
    if len(p) == 2:
        t = p[0]
        if t == "m." or t in C_HON or (t.endswith(".") and t[:-1] in C_HON):
            r = p[1].strip()
            if r:
                return r
    return s


def matching(gold, pred, reverse=False):
    cands = {}
    for gi, (gs, ge, _) in enumerate(gold):
        ov = []
        for pi, (ps, pe, _) in enumerate(pred):
            o = min(ge, pe) - max(gs, ps)
            if o > 0:
                ov.append((o, -pi) if reverse else (-o, pi))
        ov.sort()
        cands[gi] = [(-x[1] if reverse else x[1]) for x in ov]
    matched = {}

    def assign(gi, seen):
        for pi in cands[gi]:
            if pi in seen:
                continue
            seen.add(pi)
            if pi not in matched or assign(matched[pi], seen):
                matched[pi] = gi
                return True
        return False
    order = range(len(gold) - 1, -1, -1) if reverse else range(len(gold))
    for gi in order:
        assign(gi, set())
    return matched


def presence(gold_by_doc, pred_by_doc, keyfn, reverse=False):
    per = {}
    false_list = []
    for doc in gold_by_doc:
        g, p = gold_by_doc[doc], pred_by_doc[doc]
        m = matching(g, p, reverse)
        up, ug = set(m), set(m.values())
        gk, pk = collections.defaultdict(bool), collections.defaultdict(bool)
        for i, x in enumerate(g):
            gk[keyfn(x[2])] |= i in ug
        for i, x in enumerate(p):
            pk[keyfn(x[2])] |= i in up
        per[doc] = (sum(pk.values()), len(pk), sum(gk.values()), len(gk))
        false_list += ["%s/%s:%s" % (doc[0], doc[1], k) for k, v in pk.items() if not v]
    return per, sorted(false_list)


def summ(per, docs):
    a = [0, 0, 0, 0]
    for d in docs:
        for i in range(4):
            a[i] += per[d][i]
    P = a[0] / a[1] if a[1] else 0.0
    R = a[2] / a[3] if a[3] else 0.0
    F = 2 * P * R / (P + R) if P + R else 0.0
    return {"P": round(P, 4), "R": round(R, 4), "F1": round(F, 4), "pred_keys": a[1], "true_pred_keys": a[0],
            "false_pred_keys": a[1] - a[0], "gold_keys": a[3], "gold_found": a[2], "docs": len(docs)}


def pct(vals, q):
    v = sorted(vals)
    idx = q * (len(v) - 1)
    lo, hi = int(idx), min(int(idx) + 1, len(v) - 1)
    return v[lo] + (v[hi] - v[lo]) * (idx - lo)


def main():
    gold = collections.defaultdict(list)
    band = {}
    for line in open(M2A + "/m2a-ground-truth.jsonl", encoding="utf-8"):
        if line.strip():
            r = json.loads(line)
            gold[(r["v"], r["d"])].append((r["s"], r["e"], r["n"]))
            band[(r["v"], r["d"])] = r["band"]
    listed = [json.loads(x) for x in open(M2A + "/m2a-ground-truth-documents.jsonl", encoding="utf-8") if x.strip()]
    for r in listed:
        k = (r["v"], r["d"])
        assert r["mentions"] == len(gold.get(k, [])), k
        gold.setdefault(k, [])
        band[k] = r["band"]
    assert set(gold) == {(r["v"], r["d"]) for r in listed}
    gold = {k: sorted(v) for k, v in gold.items()}
    docs = sorted(gold)
    n_mentions = sum(len(v) for v in gold.values())
    vols = sorted({v for v, _ in docs})
    arms = {a: {} for a in DIRS}
    checks = {"span_slice_mismatch": 0, "heads_not_full_pass": []}
    for vol in vols:
        texts = {}
        with gzip.open(os.path.join(TEXT, vol + ".jsonl.gz"), "rt", encoding="utf-8") as h:
            for x in h:
                if x.strip():
                    r = json.loads(x)
                    texts[r["d"]] = r["t"]
        for a, dp in DIRS.items():
            if a != "E":
                hd = json.load(open(os.path.join(dp, vol + ".head.json")))
                if hd.get("sampled") is not False:
                    checks["heads_not_full_pass"].append((a, vol))
            byd = collections.defaultdict(set)
            for r in read_jsonl(dp, vol):
                byd[r["d"]].add((r["s"], r["e"], r["n"]))
            for v, d in docs:
                if v == vol:
                    arms[a][(v, d)] = sorted(byd.get(d, ()))
                    for s, e, n in arms[a][(v, d)]:
                        if texts[d][s:e] != n:
                            checks["span_slice_mismatch"] += 1
        for v, d in docs:
            if v == vol:
                for s, e, n in gold[(v, d)]:
                    if texts[d][s:e] != n:
                        checks["span_slice_mismatch"] += 1

    def ov(a, b):
        return min(a[1], b[1]) - max(a[0], b[0]) > 0
    built = {}
    built["editor"] = arms["E"]
    built["filtered_control"] = arms["FC"]
    built["filtered_sweep"] = arms["FS"]
    built["editor_union_filtered_control"] = {k: sorted(set(arms["E"][k]) | set(arms["FC"][k])) for k in docs}
    built["agreement_sweep_side"] = {k: sorted(set(arms["E"][k]) | {x for x in arms["FS"][k] if any(ov(x, y) for y in arms["FC"][k])}) for k in docs}
    built["agreement_control_side"] = {k: sorted(set(arms["E"][k]) | {x for x in arms["FC"][k] if any(ov(x, y) for y in arms["FS"][k])}) for k in docs}

    out = {"script": os.path.abspath(__file__), "sample": {"documents": len(docs), "mentions": n_mentions,
           "docs_by_band": dict(collections.Counter(band[d] for d in docs))}, "checks": checks, "arms": {}}
    bands = sorted(set(band.values()))
    by_band = {b: [d for d in docs if band[d] == b] for b in bands}
    rng = random.Random(234)
    draws = []
    for _ in range(10000):
        dr = {}
        for b in bands:
            L = by_band[b]
            dr[b] = [L[rng.randrange(len(L))] for _ in L]
        draws.append(dr)
    for name, preds in built.items():
        mention_spans = sum(len(preds[k]) for k in docs)
        strict = sum(len({(s, e) for s, e, _ in preds[k]} & {(s, e) for s, e, _ in gold[k]}) for k in docs)
        relaxed = sum(len(matching(gold[k], preds[k])) for k in docs)
        per, fl = presence(gold, preds, gkey)
        per_rev, fl_rev = presence(gold, preds, gkey, reverse=True)
        per_k2, _ = presence(gold, preds, k2)
        entry = {"spans_predicted": mention_spans, "strict_hits": strict, "relaxed_hits": relaxed,
                 "strict_P": round(strict / mention_spans, 4), "strict_R": round(strict / n_mentions, 4),
                 "strict_F1": round(2 * strict / (mention_spans + n_mentions), 4),
                 "relaxed_P": round(relaxed / mention_spans, 4), "relaxed_R": round(relaxed / n_mentions, 4),
                 "presence_gkey": summ(per, docs), "presence_gkey_reversed_tiebreak": summ(per_rev, docs),
                 "presence_census_K2": summ(per_k2, docs),
                 "presence_gkey_by_band": {b: summ(per, by_band[b]) for b in bands},
                 "false_keys_differ_under_reversed_tiebreak": sorted(set(fl) ^ set(fl_rev))}
        if name in ("agreement_sweep_side", "editor_union_filtered_control"):
            Ps, Rs = [], []
            for dr in draws:
                a = [0, 0, 0, 0]
                for b in bands:
                    for d in dr[b]:
                        for i in range(4):
                            a[i] += per[d][i]
                Ps.append(a[0] / a[1] if a[1] else 0.0)
                Rs.append(a[2] / a[3] if a[3] else 0.0)
            entry["bootstrap_95"] = {"P": [round(pct(Ps, .025), 4), round(pct(Ps, .975), 4)],
                                     "R": [round(pct(Rs, .025), 4), round(pct(Rs, .975), 4)]}
            entry["false_keys"] = fl
        out["arms"][name] = entry
    json.dump(out, open(os.path.join(OUT, "v-gold.json"), "w"), indent=1, ensure_ascii=False)
    for name, e in out["arms"].items():
        print(name, "spans", e["spans_predicted"], "strictF1", e["strict_F1"], "relaxedP", e["relaxed_P"],
              "| presence", e["presence_gkey"], "| rev", {k: e["presence_gkey_reversed_tiebreak"][k] for k in ("P", "R", "false_pred_keys")},
              "| K2", {k: e["presence_census_K2"][k] for k in ("P", "R", "pred_keys", "false_pred_keys", "gold_keys")},
              e.get("bootstrap_95", ""))
    print(json.dumps(out["checks"]), out["sample"])
    print("agreement by band", {b: (v["P"], v["R"], v["pred_keys"], v["false_pred_keys"]) for b, v in out["arms"]["agreement_sweep_side"]["presence_gkey_by_band"].items()})


if __name__ == "__main__":
    main()
