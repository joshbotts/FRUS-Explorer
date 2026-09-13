#!/usr/bin/env python3
"""vkeys.py — job D key check: per-volume distinct surfaces over the marked layer under (a) census K2 as stored in
census.json and re-derived here from census.py's definition (ONE leading honorific, 29-token list), and (b)
measure_pocom.k2_surface (repeated honorifics, its own set), which volume_guides.py actually used. Read-only."""
import sys; sys.dont_write_bytecode = True
import os, json, gzip, re, statistics, collections
W = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
E = W + "/Planning/early-era-people/feasibility-2026-09-12"
sys.path.insert(0, E + "/measure-pocom"); sys.path.insert(0, W + "/tools/semantic-harvest")
import measure_pocom as MP
c = json.load(open(E + "/measure-census/census.json"))
pv = c["arms"]["marked"]["per_volume_distinct_K2"]
src = open(E + "/measure-census/census.py").read()
hon = eval(re.search(r"HONORIFICS = (\[.*?\])", src, re.S).group(1))
alts = [re.escape(h[:-1]) + r"\." if h.endswith(".") else re.escape(h) + r"\.?" for h in hon]
HRE = re.compile(r"^(?:" + "|".join(alts) + r")\s+"); POSS = re.compile(r"(?:’s|'s|’|')$")
def k2(n):
    s = POSS.sub("", re.sub(r"\s+", " ", n.casefold()).strip()).strip()
    return HRE.sub("", s, count=1).strip() or s
vols = json.load(open(os.path.expanduser("~/frus-ner-raw/scope.json")))["volumes"]
mine, theirs = {}, {}
for v in vols:
    p = os.path.expanduser("~/frus-ner-raw/marked/" + v)
    rows = []
    for q in (p + ".jsonl", p + ".jsonl.gz"):
        if os.path.exists(q):
            rows = [json.loads(l) for l in (gzip.open(q, "rt") if q.endswith(".gz") else open(q)) if l.strip()]
    mine[v] = len({k2(r["n"]) for r in rows}); theirs[v] = len({MP.k2_surface(r["n"])[0] for r in rows})
def st(d):
    xs = [d.get(v, 0) for v in vols] if isinstance(d, dict) else d
    return {"n": len(xs), "median": statistics.median(xs), "max": max(xs), "sum": sum(xs), "argmax": max(vols, key=lambda v: d.get(v, 0))}
out = {"census_json_per_volume_distinct_K2": st(pv) if isinstance(pv, dict) else str(type(pv)),
       "census_K2_rederived": st(mine), "measure_pocom_k2_surface": st(theirs),
       "rederived_equals_census_json": (mine == pv) if isinstance(pv, dict) else None}
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "vkeys.json"), "w"), indent=1)
print(json.dumps(out, indent=1))
