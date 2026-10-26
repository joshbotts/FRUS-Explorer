# For a list of NAIDs print the series-facts-index.json row (decoded through the legend) or "none". usage: library_facts_lookup.py NAID,NAID,...
import json, sys
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
sf = json.load(open(R + "series-facts-index.json"))
for n in sys.argv[1].split(","):
    r = sf["byNaId"].get(n)
    if not r:
        print(n, "none"); continue
    out = {}
    for k, v in r.items():
        f = sf["legend"]["keys"][k]
        if f["kind"] == "index": v = sf[f["into"]][v]
        elif f["kind"] == "indexList": v = [sf[f["into"]][i] for i in v]
        out[f["field"]] = v
    print(n, json.dumps(out, ensure_ascii=False)[:500])
