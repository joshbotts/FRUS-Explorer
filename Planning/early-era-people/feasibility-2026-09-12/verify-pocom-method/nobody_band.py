# Decompose the marked from/to "known but nobody in office that year" band (40,563) by document year
# relative to POCOM's coverage, and measure Seward's unique-by-doc-year count.
import sys, json, collections
sys.path.insert(0, "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/measure-pocom")
import measure_pocom as mp, ner_store
surnames, spans, by_surname = mp.load_pocom()
pocom_min = min(a for v in spans.values() for a, b in v); pocom_max = max(b for v in spans.values() for a, b in v)
scope = ner_store.scope_volumes(mp.MARKED)
c = collections.Counter(); seward = collections.Counter(); nobody_by_decade = collections.Counter()
docyear_vs_band = collections.Counter()
for vol in scope:
    band = ner_store.band_of(vol)
    dy = mp.tei_doc_years(vol)
    for r in ner_store.volume_layer(mp.MARKED, "marked", vol):
        if r["t"] not in ("from", "to"): continue
        sur = mp.surname_of(mp.text_of(r["n"]))
        if not sur: continue
        c["with_surname"] += 1
        y = dy.get(r["d"])
        if y is None: c["undated"] += 1; continue
        bl, bh = [(lo, hi) for lo, hi, lab in ner_store.BANDS if lab == band][0]
        docyear_vs_band["in_band" if bl <= y <= bh else "before_band" if y < bl else "after_band"] += 1
        cands = by_surname.get(sur)
        if not cands: continue
        c["known"] += 1
        live = mp.live_count(cands, spans, y, y)
        if live == 0:
            c["nobody"] += 1
            if y < pocom_min - 1: c["nobody_doc_before_pocom"] += 1
            nobody_by_decade[(y // 10) * 10] += 1
        elif live == 1:
            c["unique"] += 1
            if sur == "Seward": seward["unique"] += 1; seward[("unique_year", y)] += 1
        else:
            c["several"] += 1
        if sur == "Seward": seward["known"] += 1
print(json.dumps({"pocom_span_years": [pocom_min, pocom_max], "counts": dict(c),
                  "docyear_vs_volume_band": dict(docyear_vs_band),
                  "nobody_by_decade_top": sorted(nobody_by_decade.items(), key=lambda kv: -kv[1])[:12],
                  "seward": {str(k): v for k, v in seward.items()}}, indent=1))
