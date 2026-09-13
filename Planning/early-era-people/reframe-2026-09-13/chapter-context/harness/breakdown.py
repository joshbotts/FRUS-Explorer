#!/usr/bin/env python3
"""Category mix of the shown rows (harness output only). stdlib."""
import collections, json, re
docs = [json.loads(l) for l in open("frus-pre1906-classified.jsonl")]
band = lambda y: None if y is None else ("1861-1899" if 1861 <= y <= 1899 else "1900-1905" if 1900 <= y <= 1905 else None)
mix = {b: collections.Counter() for b in ("1861-1899", "1900-1905")}
consdl = collections.Counter()
for d in docs:
    b = band(d["appYear"])
    if not b: continue
    key = "+".join(sorted(f"{r['category']}/{r['confidence']}" for r in d["shown"])) or "(nothing)"
    mix[b][key] += 1
    dl = (d["dateline"] or "").lower()
    if "consulate" in dl or "consular" in dl: consdl[b] += 1
out = {"shown_category_mix": {b: c.most_common(20) for b, c in mix.items()}, "docs_with_consulate_or_consular_in_dateline": dict(consdl)}
vids = sorted({d["volume"] for d in docs})
out["volumes_in_set"] = len(vids)
out["volume_ids_year_ge_1906_in_set"] = [v for v in vids if int(re.match(r"frus(\d{4})", v).group(1)) >= 1906]
out["volume_ids_1861_1899"] = [v for v in vids if 1861 <= int(re.match(r"frus(\d{4})", v).group(1)) <= 1899]
json.dump(out, open("breakdown.json", "w"), indent=1)
print(json.dumps(out, indent=1))
