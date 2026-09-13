#!/usr/bin/env python3
"""measure-claude-jobs/pools.py — the candidate pools Claude verification jobs A and B would read (#234 reframe).

Read-only over: the editors' marked layer (~/frus-ner-raw/marked), the filtered NLTagger control
(~/frus-ner-raw-control-filtered/detected), the filtered Qwen3-14B sweep (~/frus-ner-raw-filtered/detected),
the R-0 text layer (~/frus-semantic-raw/text), and the M2a document list. Stdlib only. Writes pools.json here.

Arms (the feasibility assessment's §2.2 / §4.b2 construction, from measure-grains/grains.py lines 312-319):
  INT_S  = filtered-sweep spans overlapping >= 1 filtered-control span in the same document (sweep side)
  AGREE  = editor ∪ INT_S (exact (s, e, surface) de-duplication)  -> job B's population
Disagreement pools (job A):
  control_only      = filtered-control spans overlapping no filtered-sweep span
  sweep_only        = filtered-sweep spans overlapping no filtered-control span
  *_net             = the same, minus spans overlapping an editor span (the editor layer already covers them)
  union_minus_agree_exact = (editor ∪ FC ∪ FS) minus AGREE, by exact span triple (the literal definition)
  union_minus_agree_net   = the exact difference minus spans overlapping ANY AGREE span (the real queue)
Overlap = more than 0 characters in common, the scorer's rule. Context window = [s-WIN, e+WIN) clipped to the document.
"""
import sys
sys.dont_write_bytecode = True
import os, json, bisect, collections, time, ast, math

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
SP = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad"
STUDIO = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio"
sys.path.insert(0, REPO + "/tools/semantic-harvest")
import ner_store  # noqa: E402

X = os.path.expanduser
MARKED, FC_STORE, FS_STORE, TEXT = X("~/frus-ner-raw"), X("~/frus-ner-raw-control-filtered"), X("~/frus-ner-raw-filtered"), X("~/frus-semantic-raw/text")
GOLD_DOCS = STUDIO + "/frus-m2a/m2a-ground-truth-documents.jsonl"
WIN = int(os.environ.get("WIN", "300"))
PACK = (8000, 20000, 40000)
LIST_OVERHEAD = 12   # chars per listed candidate beyond its surface (id/offsets), cost_model.py shape B central

# presence key: grains.py's surface_key, with its HONORIFICS list read from grains.py by AST (not retyped)
_g = ast.parse(open(SP + "/measure-grains/grains.py").read())
HONORIFICS = next(ast.literal_eval(n.value) for n in _g.body if isinstance(n, ast.Assign) and getattr(n.targets[0], "id", "") == "HONORIFICS")
HSET = set(HONORIFICS)
import re  # noqa: E402
POSSESSIVE = re.compile(r"(?:['’]s|['’])$")


def surface_key(surface):
    s = " ".join(surface.casefold().split())
    s = POSSESSIVE.sub("", s).strip()
    t = s.split()
    i = 0
    while i < len(t) and t[i].rstrip(".") in HSET:
        i += 1
    return " ".join(t[i:]) or s


class Against:
    """any-overlap test against a span list: sorted starts + prefix max of ends; zero-length spans never overlap."""
    def __init__(self, spans):
        sp = sorted((s, e) for s, e, _ in spans if e > s)
        self.starts = [s for s, _ in sp]
        self.pmax, m = [], -1
        for _, e in sp:
            m = e if e > m else m
            self.pmax.append(m)

    def hit(self, s, e):
        if e <= s or not self.starts:
            return False
        i = bisect.bisect_left(self.starts, e)
        return i > 0 and self.pmax[i - 1] > s


POOLS = ["editor", "filtered_control", "filtered_sweep", "int_sweep_side", "agree",
         "control_only", "sweep_only", "control_only_net", "sweep_only_net",
         "union3", "union_minus_agree_exact", "union_minus_agree_net"]


class Acc:
    def __init__(self):
        self.c = collections.Counter()
        self.fill = {t: 0 for t in PACK}

    def add(self, pool, L):
        if not pool:
            return
        c = self.c
        c["docs"] += 1
        c["spans"] += len(pool)
        c["surface_chars"] += sum(len(n) for _, _, n in pool)
        cl, cur = 0, None
        for s, e, _ in pool:                       # pool is sorted
            if cur is None or s >= cur:
                cl += 1
                cur = e
            elif e > cur:
                cur = e
        c["mention_clusters"] += cl
        wins = [(max(0, s - WIN), min(L, e + WIN)) for s, e, _ in pool]
        c["window_chars_per_span"] += sum(b - a for a, b in wins)
        merged, ca, cb = 0, None, None
        for a, b in sorted(wins):
            if ca is None or a > cb:
                if ca is not None:
                    merged += cb - ca
                ca, cb = a, b
            elif b > cb:
                cb = b
        merged += cb - ca
        c["window_chars_merged_per_doc"] += merged
        seen = {}
        for (s, e, n), w in zip(pool, wins):
            k = surface_key(n)
            if k not in seen:
                seen[k] = w[1] - w[0]
        c["doc_keys"] += len(seen)
        c["window_chars_per_doc_key"] += sum(seen.values())
        listing = sum(len(n) + LIST_OVERHEAD for _, _, n in pool)
        c["listing_chars"] += listing
        p = merged + listing                      # one per-document request: merged windows + candidate list
        c["docs_over_40000_payload"] += p > 40000
        for T in PACK:
            if p > T:
                c["req_pack%d" % T] += math.ceil(p / T)
            elif self.fill[T] + p > T:
                c["req_pack%d" % T] += 1
                self.fill[T] = p
            else:
                self.fill[T] += p

    def close(self):
        out = dict(self.c)
        for T in PACK:
            out["req_pack%d" % T] = out.get("req_pack%d" % T, 0) + (1 if self.fill[T] else 0)
        return out


def by_doc(rows):
    g = collections.defaultdict(set)
    for r in rows:
        g[r["d"]].add((r["s"], r["e"], r["n"]))
    return g


def main():
    t0 = time.time()
    vols = ner_store.scope_volumes(MARKED)
    gold = {(j["v"], j["d"]) for j in map(json.loads, open(GOLD_DOCS))}
    ACC = collections.defaultdict(Acc)              # (scope, pool) -> Acc ; scope = all | band | gold
    PC = collections.Counter()
    per_gold_doc = []
    for vi, v in enumerate(vols):
        band = ner_store.band_of(v)
        texts = ner_store.volume_text(TEXT, v)
        layers = {"editor": ner_store.volume_layer(MARKED, "marked", v),
                  "filtered_control": ner_store.volume_layer(FC_STORE, "detected", v),
                  "filtered_sweep": ner_store.volume_layer(FS_STORE, "detected", v)}
        G = {}
        for name, rows in layers.items():
            PC["rows:" + name] += len(rows)
            G[name] = by_doc(rows)
            for d, sp in G[name].items():
                PC["spans:" + name] += len(sp)
                t = texts.get(d)
                if t is None:
                    PC["spans_doc_absent_from_text:" + name] += len(sp)
                    continue
                PC["span_text_mismatch:" + name] += sum(1 for s, e, n in sp if t[s:e] != n)
        for d, t in texts.items():
            PC["text_docs"] += 1
            PC["text_chars"] += len(t)
            PC["text_words_whitespace"] += len(t.split())
            L = len(t)
            E = sorted(G["editor"].get(d, ()))
            FC = sorted(G["filtered_control"].get(d, ()))
            FS = sorted(G["filtered_sweep"].get(d, ()))
            aFC, aFS, aE = Against(FC), Against(FS), Against(E)
            INT = [x for x in FS if aFC.hit(x[0], x[1])]
            AG = sorted(set(E) | set(INT))
            CO = [x for x in FC if not aFS.hit(x[0], x[1])]
            SO = [x for x in FS if not aFC.hit(x[0], x[1])]
            U3 = set(E) | set(FC) | set(FS)
            DX = sorted(U3 - set(AG))
            aAG = Against(AG)
            P = {"editor": E, "filtered_control": FC, "filtered_sweep": FS, "int_sweep_side": INT, "agree": AG,
                 "control_only": CO, "sweep_only": SO,
                 "control_only_net": [x for x in CO if not aE.hit(x[0], x[1])],
                 "sweep_only_net": [x for x in SO if not aE.hit(x[0], x[1])],
                 "union3": sorted(U3), "union_minus_agree_exact": DX,
                 "union_minus_agree_net": [x for x in DX if not aAG.hit(x[0], x[1])]}
            scopes = ["all", "band:" + band] + (["gold"] if (v, d) in gold else [])
            for sc in scopes:
                for name in POOLS:
                    ACC[(sc, name)].add(P[name], L)
            if (v, d) in gold:
                per_gold_doc.append({"v": v, "d": d, "chars": L, **{name: len(P[name]) for name in POOLS}})
        if (vi + 1) % 25 == 0:
            print("[%d/%d] %s %.0fs" % (vi + 1, len(vols), v, time.time() - t0), file=sys.stderr)
    res = {"generated_by": os.path.abspath(__file__), "window_chars_each_side": WIN, "pack_targets_chars": PACK,
           "list_overhead_chars_per_candidate": LIST_OVERHEAD, "volumes": len(vols),
           "positive_control": dict(PC),
           "positive_control_expected_DOCUMENTED": {"rows:editor": 245747, "rows:filtered_control": 1261852, "rows:filtered_sweep": 2597043,
                                                    "text_docs (TEI-rule scope)": 197534, "text_chars": 679401514,
                                                    "gold spans (stage1_sizing.json)": {"editor": 88, "filtered_control": 316, "filtered_sweep": 736, "union3": 906}},
           "chars_per_whitespace_word": PC["text_chars"] / PC["text_words_whitespace"],
           "pools": {}, "gold_docs_found": len(per_gold_doc), "per_gold_doc": per_gold_doc, "secs": round(time.time() - t0, 1)}
    for (sc, name), acc in sorted(ACC.items()):
        res["pools"].setdefault(sc, {})[name] = acc.close()
    json.dump(res, open(os.path.join(HERE, "pools.json"), "w"), indent=1, sort_keys=True)
    print(json.dumps({k: res["pools"]["all"][k] for k in ("agree", "control_only", "sweep_only", "union_minus_agree_net")}, indent=1))
    print(json.dumps(res["positive_control"], indent=1), "secs", res["secs"])


if __name__ == "__main__":
    main()
