#!/usr/bin/env python3
"""Part 4: Wilson 95% intervals at plausible rates for keyed subsets, and the POCOM class mix of the
300 m1a eval rows (verbatim POCOM rule, the row's own `year` column). Read-only."""
import csv, json, math, sys, collections
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, REPO + "/Planning/early-era-people/feasibility-2026-09-12/measure-pocom")
import measure_pocom as mp

def wilson(k, n, z=1.959964):
    p = k / n; den = 1 + z*z/n; c = (p + z*z/(2*n)) / den
    h = z*math.sqrt(p*(1-p)/n + z*z/(4*n*n)) / den
    return round(c - h, 4), round(c + h, 4)

out = {"wilson_95": {}}
for n in (25, 33, 50, 100, 300):
    for p in (0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 1.0):
        k = round(p * n); lo, hi = wilson(k, n)
        out["wilson_95"]["n=%d k=%d (%.0f%%)" % (n, k, 100*k/n)] = {"lo": lo, "hi": hi, "half_width_pts": round(100*(hi-lo)/2, 1)}
_, spans, by_surname = mp.load_pocom()
rows = list(csv.DictReader(open(REPO + "/Planning/early-era-people/m1a-eval-candidates.csv")))
mix = collections.defaultdict(collections.Counter)
for r in rows:
    y = int(r["year"]); grp = "pre1910" if y < 1910 else "1910+"
    sur = mp.surname_of(r["name_as_printed"])
    c = by_surname.get(sur) if sur else None
    if not c: cls = "unknown"
    else:
        live = sum(1 for s in c if any(a-1 <= y <= b+1 for a, b in spans[s]))
        cls = "nobody" if live == 0 else "one" if live == 1 else "several"
    mix[grp][cls] += 1; mix["all"][cls] += 1
    mix["vol:" + r["volume"]][cls] += 1
out["eval_rows"] = len(rows)
out["eval_rows_pocom_class"] = {k: dict(v) for k, v in sorted(mix.items())}
out["eval_rows_surname_column_matches_surname_of"] = sum(1 for r in rows if mp.surname_of(r["name_as_printed"]) == r["surname"])
json.dump(out, open("gate.json", "w"), indent=1, sort_keys=True)
print(json.dumps(out, indent=1, sort_keys=True))
