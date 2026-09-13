#!/usr/bin/env python3
"""Independent re-derivation of the measure-census figures. Stdlib only, read-only.
Does NOT import ner_store or census.py; opens the store files directly and keys surfaces
with a token-based honorific rule written from the report's stated spec."""
import gzip, json, os, re, statistics, sys, time
from collections import Counter

HOME = os.path.expanduser("~")
STUDIO = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw"
OUT = os.path.dirname(os.path.abspath(__file__))
ARMS = {
    "marked":           (HOME + "/frus-ner-raw/marked"),
    "raw_control":      (HOME + "/frus-ner-raw-control/detected"),
    "filtered_control": (HOME + "/frus-ner-raw-control-filtered/detected"),
    "raw_sweep":        (STUDIO + "/detected"),
    "filtered_sweep":   (HOME + "/frus-ner-raw-filtered/detected"),
}
UNIONS = {"union_marked_filtered_control": ("marked", "filtered_control"),
          "union_marked_filtered_sweep": ("marked", "filtered_sweep")}

HON = {"mr","mrs","miss","dr","sir","hon","general","colonel","captain","major","admiral","señor",
       "monsieur","herr","mme","messrs","rev","judge","governor","president","minister","count",
       "baron","lord","lady","prince","king","queen"}
HON_TOKENS = HON | {h + "." for h in HON} | {"m."}

def k1(n):
    s = " ".join(n.casefold().split())
    for suf in ("’s", "'s", "’", "'"):
        if s.endswith(suf):
            s = s[:-len(suf)].strip()
            break
    return s

def k2(s):
    parts = s.split(" ", 1)
    if len(parts) == 2 and parts[0] in HON_TOKENS:
        rest = parts[1].strip()
        return rest if rest else s
    return s

def band(vol):
    y = int(re.search(r"frus(\d{4})", vol).group(1))
    if y <= 1899: return "1861-1899"
    if y <= 1929: return "1900-1929"
    if y <= 1945: return "1930-1945"
    return "1946-"

def read_rows(d, vol):
    cands = [p for p in (d + "/" + vol + ".jsonl", d + "/" + vol + ".jsonl.gz") if os.path.exists(p)]
    assert len(cands) == 1, (d, vol, cands)
    p = cands[0]
    op = gzip.open if p.endswith(".gz") else open
    with op(p, "rt", encoding="utf-8") as fh:
        return [json.loads(l) for l in fh if l.strip()]

def read_head(d, vol):
    return json.load(open(d + "/" + vol + ".head.json"))

def conc(cnt):
    tot = sum(cnt.values())
    def sh(pred): return sum(c for c in cnt.values() if pred(c))
    return {"mentions": tot, "distinct": len(cnt),
            "single": sh(lambda c: c == 1), "ge5": sh(lambda c: c >= 5), "ge20": sh(lambda c: c >= 20),
            "share_single": round(sh(lambda c: c == 1) / tot, 4), "share_ge5": round(sh(lambda c: c >= 5) / tot, 4),
            "share_ge20": round(sh(lambda c: c >= 20) / tot, 4),
            "surf_single": sum(1 for c in cnt.values() if c == 1), "surf_ge5": sum(1 for c in cnt.values() if c >= 5),
            "surf_ge20": sum(1 for c in cnt.values() if c >= 20), "top30": cnt.most_common(30)}

t0 = time.time()
scope = json.load(open(HOME + "/frus-ner-raw/scope.json"))
vols = scope["volumes"]
# independent check: directory listing agrees with scope.json for every arm
for a, d in ARMS.items():
    heads = sorted(f[:-10] for f in os.listdir(d) if f.endswith(".head.json"))
    assert heads == sorted(vols), a
    bodies = sorted(re.sub(r"\.jsonl(\.gz)?$", "", f) for f in os.listdir(d) if ".jsonl" in f)
    assert bodies == sorted(vols), a
assert len(vols) == 267

class A:
    def __init__(s):
        s.rows = 0; s.k1 = Counter(); s.k2 = Counter(); s.pairs = 0; s.pairs_band = Counter()
        s.docs = 0; s.docs_band = Counter(); s.rows_band = Counter(); s.only_ft = 0
        s.pv_k2 = {}; s.pv_pairs = {}; s.dedup = 0; s.overlap = 0
    def add(s, vol, b, docmap):  # docmap: doc -> list of (k2, is_ft)
        vk2 = set(); vp = 0
        for doc, ents in docmap.items():
            ks = {k for k, _ in ents}
            vk2 |= ks; vp += len(ks)
            if all(f for _, f in ents): s.only_ft += 1
        s.pairs += vp; s.pairs_band[b] += vp; s.docs += len(docmap); s.docs_band[b] += len(docmap)
        s.pv_k2[vol] = len(vk2); s.pv_pairs[vol] = vp

acc = {a: A() for a in list(ARMS) + list(UNIONS)}
typed = Counter(); docs_total = 0; docs_band = Counter(); zero_marked = []; head_doc_mismatch = []; body_head_mismatch = []
for i, vol in enumerate(vols):
    b = band(vol)
    mh = read_head(ARMS["marked"], vol); nd = mh["docs"]; docs_total += nd; docs_band[b] += nd
    if mh["mentions"] == 0: zero_marked.append((vol, nd))
    per = {}
    for a, d in ARMS.items():
        rows = read_rows(d, vol); h = read_head(d, vol)
        hd = h.get("docs", h.get("docs_in_volume"))
        if hd != nd: head_doc_mismatch.append((a, vol, hd, nd))
        if h["mentions"] != len(rows): body_head_mismatch.append((a, vol, h["mentions"], len(rows)))
        ac = acc[a]; ac.rows += len(rows); ac.rows_band[b] += len(rows)
        dm = {}; spans = {}
        for r in rows:
            x1 = k1(r["n"]); x2 = k2(x1)
            ac.k1[x1] += 1; ac.k2[x2] += 1
            ft = False
            if a == "marked":
                t = r.get("t"); typed["from" if t == "from" else "to" if t == "to" else "untyped"] += 1
                ft = t in ("from", "to")
            dm.setdefault(r["d"], []).append((x2, ft))
            spans.setdefault(r["d"], set()).add((r["s"], r["e"]))
        per[a] = (dm, spans, x1 if rows else None)
        ac.add(vol, b, dm)
    for u, (c1, c2) in UNIONS.items():
        ac = acc[u]; m = {}
        for c in (c1, c2):
            dm = per[c][0]
            for doc, ents in dm.items(): m.setdefault(doc, []).extend(ents)
            ac.rows += sum(len(v) for v in dm.values()); ac.rows_band[b] += sum(len(v) for v in dm.values())
        sp1, sp2 = per[c1][1], per[c2][1]
        alld = set(sp1) | set(sp2)
        dd = sum(len(sp1.get(doc, set()) | sp2.get(doc, set())) for doc in alld)
        ov = sum(len(sp1.get(doc, set()) & sp2.get(doc, set())) for doc in alld)
        ac.dedup += dd; ac.overlap += ov
        ac.add(vol, b, m)
    if (i + 1) % 50 == 0: print(i + 1, round(time.time() - t0), file=sys.stderr)
for u, (c1, c2) in UNIONS.items():
    acc[u].k1 = acc[c1].k1 + acc[c2].k1; acc[u].k2 = acc[c1].k2 + acc[c2].k2

res = {"docs_total": docs_total, "docs_band": dict(docs_band), "typed": dict(typed), "zero_marked": zero_marked,
       "head_doc_mismatch": head_doc_mismatch, "body_head_mismatch": body_head_mismatch, "arms": {}}
for a, ac in acc.items():
    kv = list(ac.pv_k2.values()); pv = list(ac.pv_pairs.values())
    res["arms"][a] = {
        "rows": ac.rows, "rows_band": dict(ac.rows_band), "K1": len(ac.k1), "K2": len(ac.k2),
        "pairs": ac.pairs, "pairs_band": dict(ac.pairs_band), "docs": ac.docs, "docs_share": round(ac.docs / docs_total, 4),
        "docs_band": {k: (v, round(v / docs_band[k], 4)) for k, v in ac.docs_band.items()},
        "only_ft": ac.only_ft, "only_ft_share": round(ac.only_ft / ac.docs, 4),
        "concK2": conc(ac.k2), "concK1": {k: v for k, v in conc(ac.k1).items() if k != "top30"},
        "pv_k2": {"median": statistics.median(kv), "max": max(kv), "max_vol": max(ac.pv_k2, key=ac.pv_k2.get), "min": min(kv)},
        "pv_pairs": {"median": statistics.median(pv), "max": max(pv)},
        "dedup_span": ac.dedup, "overlap_span": ac.overlap,
    }
res["elapsed"] = round(time.time() - t0, 1)
json.dump(res, open(OUT + "/verify.json", "w"), indent=1, ensure_ascii=False)
print("done", res["elapsed"])
