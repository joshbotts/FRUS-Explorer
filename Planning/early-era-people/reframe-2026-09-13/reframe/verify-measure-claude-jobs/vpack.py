#!/usr/bin/env python3
"""vpack.py — independent next-fit request count for the queue (Q) and agreement arm (AG): one per-document payload =
merged ±300 windows + candidate listing (surface + 12 chars), documents in scope order then text-file order; a payload
larger than the target gets its own ceil(p/T) requests and does not close the open request. Read-only. Stdlib only."""
import sys; sys.dont_write_bytecode = True
import os, json, gzip, bisect, math
X = os.path.expanduser
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import vpools as VP
T = (8000, 20000, 40000)
def main():
    vols = json.load(open(X("~/frus-ner-raw/scope.json")))["volumes"]
    st = {p: {t: {"req": 0, "fill": 0} for t in T} for p in ("Q", "AG")}
    over = {"Q": 0, "AG": 0}
    for v in vols:
        text = {r["d"]: r["t"] for r in VP.rows(X("~/frus-semantic-raw/text/") + v)}
        L = {}
        for lab, base in (("E", "~/frus-ner-raw/marked/"), ("FC", "~/frus-ner-raw-control-filtered/detected/"), ("FS", "~/frus-ner-raw-filtered/detected/")):
            g = {}
            for r in VP.rows(X(base) + v) or []:
                g.setdefault(r["d"], set()).add((r["s"], r["e"], r["n"]))
            L[lab] = g
        for d, t in text.items():
            E, FC, FS = L["E"].get(d, set()), L["FC"].get(d, set()), L["FS"].get(d, set())
            cFC = VP.Cover(FC)
            AG = E | {x for x in FS if cFC.hits(x[0], x[1])}
            cAG = VP.Cover(AG)
            Q = {x for x in (E | FC | FS) - AG if not cAG.hits(x[0], x[1])}
            for name, pool in (("Q", Q), ("AG", AG)):
                if not pool:
                    continue
                p = VP.merged_len([(max(0, s - 300), min(len(t), e + 300)) for s, e, _ in pool]) + sum(len(n) + 12 for _, _, n in pool)
                over[name] += p > 40000
                for tt in T:
                    S = st[name][tt]
                    if p > tt:
                        S["req"] += math.ceil(p / tt)
                    elif S["fill"] and S["fill"] + p > tt:
                        S["req"] += 1; S["fill"] = p
                    else:
                        S["fill"] += p
    out = {name: {"req_pack%d" % tt: st[name][tt]["req"] + (1 if st[name][tt]["fill"] else 0) for tt in T} for name in st}
    out["docs_over_40000"] = over
    json.dump(out, open(os.path.join(HERE, "vpack.json"), "w"), indent=1)
    print(json.dumps(out))
if __name__ == "__main__":
    main()
