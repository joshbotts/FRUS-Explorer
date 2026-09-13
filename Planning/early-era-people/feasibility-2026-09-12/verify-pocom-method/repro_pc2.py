# Reproduce PC-2: M1a Measurement-3 loop with and without the seg[:8000] cut, over the 12 volumes.
import sys, json, re, collections
sys.path.insert(0, "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/measure-pocom")
import measure_pocom as mp
surnames, spans, by_surname = mp.load_pocom()
sample = json.load(open(mp.M1A_SURVEY))["sample"]
out = {}
for cut in (8000, None):
    n = known = unique = 0
    undated_fromto = 0
    for v in sample:
        t = open(f"{mp.VOLUMES}/{v}.xml", encoding="utf-8", errors="replace").read()
        for seg in mp.DOCSPLIT.split(t)[1:]:
            ym = mp.DOCDATE.search(seg[:600])
            body = seg if cut is None else seg[:cut]
            if not ym:
                undated_fromto += sum(1 for _, raw in mp.FROMTO.findall(body) if mp.surname_of(mp.text_of(raw)))
                continue
            year = int(ym.group(1))
            for _, raw in mp.FROMTO.findall(body):
                sur = mp.surname_of(mp.text_of(raw))
                if not sur: continue
                n += 1
                cands = by_surname.get(sur)
                if not cands: continue
                known += 1
                live = [s for s in cands if any(a - 1 <= year <= b + 1 for a, b in spans[s])]
                if len(live) == 1: unique += 1
    out[str(cut)] = {"names_with_surname_dated": n, "known": known, "unique": unique,
                     "fromto_with_surname_in_undated_docs": undated_fromto,
                     "share_known": round(known/n,4), "share_unique": round(unique/n,4)}
# Seward officeholders
sew = sorted(by_surname.get("Seward", []))
out["seward"] = {s: spans[s] for s in sew}
print(json.dumps(out, indent=1))
