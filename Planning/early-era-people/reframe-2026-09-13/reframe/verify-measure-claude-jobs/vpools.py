#!/usr/bin/env python3
"""verify-measure-claude-jobs/vpools.py — INDEPENDENT re-derivation of the job A / job B pools.

Own readers (gzip/json, not ner_store), own overlap test (merged coverage intervals, not prefix-max), own band
function, own key (the feasibility §2.2 presence key: casefold, whitespace, trailing possessive, repeated leading
honorifics from grains.py's 74-token list, parsed from the file text by regex). Read-only. Stdlib only.
Adds method probes the measured run did not report:
  * queue (doc, key) pairs whose key is ALREADY in the agreement arm for that document (no presence-grain gain)
  * on the 64 gold docs: lenient (any-overlap) truth of queue pairs and of gold keys, per arm
"""
import sys
sys.dont_write_bytecode = True
import os, re, json, gzip, bisect, collections, time

X = os.path.expanduser
HERE = os.path.dirname(os.path.abspath(__file__))
STUDIO = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio"
GRAINS = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/Planning/early-era-people/feasibility-2026-09-12/measure-grains/grains.py"
WIN = 300

src = open(GRAINS).read()
block = re.search(r"HONORIFICS = \[(.*?)\]", src, re.S).group(1)
HON = set(re.findall(r'"([^"]+)"', block))
assert len(re.findall(r'"([^"]+)"', block)) == 74, len(re.findall(r'"([^"]+)"', block))
POSS = re.compile(r"(?:['’]s|['’])$")


def key(n):
    s = " ".join(n.casefold().split())
    s = POSS.sub("", s).strip()
    t = s.split()
    i = 0
    while i < len(t) and t[i].rstrip(".") in HON:
        i += 1
    return " ".join(t[i:]) or s


def band(v):
    y = int(re.search(r"frus(\d{4})", v).group(1))
    return "1861-1899" if y <= 1899 else "1900-1929" if y <= 1929 else "1930-1945" if y <= 1945 else "1946-"


def rows(path_noext):
    for p in (path_noext + ".jsonl", path_noext + ".jsonl.gz"):
        if os.path.exists(p):
            op = gzip.open if p.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8") as f:
                return [json.loads(l) for l in f if l.strip()]
    return None


class Cover:
    def __init__(self, spans):
        iv = sorted((s, e) for s, e, _ in spans if e > s)
        self.a, self.b = [], []
        for s, e in iv:
            if self.b and s <= self.b[-1]:
                if e > self.b[-1]:
                    self.b[-1] = e
            else:
                self.a.append(s); self.b.append(e)

    def hits(self, s, e):
        if e <= s:
            return False
        i = bisect.bisect_left(self.a, e) - 1
        return i >= 0 and self.b[i] > s


def merged_len(ivs):
    tot, ca, cb = 0, None, None
    for a, b in sorted(ivs):
        if ca is None or a > cb:
            if ca is not None:
                tot += cb - ca
            ca, cb = a, b
        elif b > cb:
            cb = b
    return tot + (cb - ca if ca is not None else 0)


def main():
    t0 = time.time()
    vols = json.load(open(X("~/frus-ner-raw/scope.json")))["volumes"]
    gold_docs = {(j["v"], j["d"]) for j in map(json.loads, open(STUDIO + "/frus-m2a/m2a-ground-truth-documents.jsonl"))}
    gold_m = collections.defaultdict(list)
    for j in map(json.loads, open(STUDIO + "/frus-m2a/m2a-ground-truth.jsonl")):
        gold_m[(j["v"], j["d"])].append((j["s"], j["e"], j["n"]))
    C = collections.Counter()
    G = collections.Counter()
    B = collections.Counter()
    for v in vols:
        bd = band(v)
        text = {r["d"]: r["t"] for r in rows(X("~/frus-semantic-raw/text/") + v)}
        L = {}
        for lab, base in (("E", X("~/frus-ner-raw/marked/")), ("FC", X("~/frus-ner-raw-control-filtered/detected/")), ("FS", X("~/frus-ner-raw-filtered/detected/"))):
            rr = rows(base + v) or []
            C["rows:" + lab] += len(rr)
            g = collections.defaultdict(set)
            for r in rr:
                g[r["d"]].add((r["s"], r["e"], r["n"]))
                t = text.get(r["d"])
                if t is None:
                    C["row_doc_not_in_text:" + lab] += 1
                elif t[r["s"]:r["e"]] != r["n"]:
                    C["row_text_mismatch:" + lab] += 1
            L[lab] = g
        for d, t in text.items():
            C["docs"] += 1; C["chars"] += len(t)
            E, FC, FS = L["E"].get(d, set()), L["FC"].get(d, set()), L["FS"].get(d, set())
            cE, cFC, cFS = Cover(E), Cover(FC), Cover(FS)
            INT = {x for x in FS if cFC.hits(x[0], x[1])}
            AG = E | INT
            CO = {x for x in FC if not cFS.hits(x[0], x[1])}
            SO = {x for x in FS if not cFC.hits(x[0], x[1])}
            U3 = E | FC | FS
            DX = U3 - AG
            cAG = Cover(AG)
            Q = {x for x in DX if not cAG.hits(x[0], x[1])}
            agk = {key(n) for _, _, n in AG}
            P = {"E": E, "FC": FC, "FS": FS, "INT": INT, "AG": AG, "CO": CO, "SO": SO,
                 "CO_net": {x for x in CO if not cE.hits(x[0], x[1])}, "SO_net": {x for x in SO if not cE.hits(x[0], x[1])},
                 "U3": U3, "DX": DX, "Q": Q}
            isg = (v, d) in gold_docs
            for name, pool in P.items():
                if not pool:
                    continue
                ks = {key(n) for _, _, n in pool}
                for tgt in ((C,) + ((G,) if isg else ())):
                    tgt["docs:" + name] += 1
                    tgt["spans:" + name] += len(pool)
                    tgt["pairs:" + name] += len(ks)
                    if name in ("Q", "CO", "SO", "DX"):
                        tgt["pairs_key_not_in_AG:" + name] += len(ks - agk)
                if name in ("AG", "Q"):
                    B["spans:%s:%s" % (name, bd)] += len(pool)
                    B["pairs:%s:%s" % (name, bd)] += len(ks)
                    wins = [(max(0, s - WIN), min(len(t), e + WIN)) for s, e, _ in pool]
                    C["win_unmerged:" + name] += sum(b - a for a, b in wins)
                    C["win_merged:" + name] += merged_len(wins)
                    C["listing:" + name] += sum(len(n) + 12 for _, _, n in pool)
            if isg:
                gm = gold_m.get((v, d), [])
                cG = Cover(gm)
                gk = collections.defaultdict(list)
                for s, e, n in gm:
                    gk[key(n)].append((s, e))
                G["gold_keys"] += len(gk)
                G["gold_mentions"] += len(gm)
                for arm in ("U3", "AG", "E", "FC", "FS"):
                    cov = Cover(P[arm])
                    G["gold_keys_found_lenient:" + arm] += sum(1 for spans in gk.values() if any(cov.hits(s, e) for s, e in spans))
                qk = collections.defaultdict(list)
                for s, e, n in Q:
                    qk[key(n)].append((s, e))
                for k2, spans in qk.items():
                    tr = any(cG.hits(s, e) for s, e in spans)
                    G["Q_pairs_lenient_true"] += tr
                    G["Q_pairs_lenient_true_key_not_in_AG"] += tr and (k2 not in agk)
                    G["Q_pairs_key_in_AG"] += (k2 in agk)
                    G["Q_pairs_key_is_gold_key"] += (k2 in gk)
                    G["Q_pairs_key_is_gold_key_not_in_AG"] += (k2 in gk) and (k2 not in agk)
                for arm in ("U3", "AG"):
                    ak = collections.defaultdict(list)
                    for s, e, n in P[arm]:
                        ak[key(n)].append((s, e))
                    G["pairs_lenient_true:" + arm] += sum(1 for spans in ak.values() if any(cG.hits(s, e) for s, e in spans))
    out = {"script": os.path.abspath(__file__), "volumes": len(vols), "honorifics": len(HON), "all": dict(C), "gold": dict(G), "bands": dict(B), "secs": round(time.time() - t0, 1)}
    json.dump(out, open(os.path.join(HERE, "vpools.json"), "w"), indent=1, sort_keys=True)
    print(json.dumps(out, indent=1, sort_keys=True))


if __name__ == "__main__":
    main()
