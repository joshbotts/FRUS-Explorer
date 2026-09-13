#!/usr/bin/env python3
"""Coverage over the harness output. stdlib only. Reads the Swift harness's JSONL; performs NO
classification of its own (every category/geo key below was produced by the app's code)."""
import collections, json, re, sys

H = sys.argv[1] if len(sys.argv) > 1 else "."
docs = [json.loads(l) for l in open(f"{H}/frus-pre1906-classified.jsonl")]
vols = {v["volume"]: v for v in (json.loads(l) for l in open(f"{H}/frus-pre1906-volumes.jsonl"))}

DIPLO = {"diplomaticDespatches", "diplomaticInstructions", "notesToForeignMissions"}
LEG = {"notesFromForeignMissions"}
CONS = {"consularDespatches"}
GEO = DIPLO | LEG | CONS


def band_of_year(y):
    if y is None: return "noYear"
    if y < 1861: return "pre-1861"
    if y <= 1899: return "1861-1899"
    if y <= 1905: return "1900-1905"
    return "1906+"


def vol_year(vid):
    return int(re.match(r"frus(\d{4})", vid).group(1))


def outcome(d):
    cats = {r["category"] for r in d["shown"]}
    flags = {
        "a_diplomatic_country": bool(cats & DIPLO),
        "b_consular_post": bool(cats & CONS),
        "c_foreign_legation": bool(cats & LEG),
        "e_date_only_series": bool(cats - GEO),
    }
    if flags["a_diplomatic_country"]: ex = "a_diplomatic_country"
    elif flags["c_foreign_legation"]: ex = "c_foreign_legation"
    elif flags["b_consular_post"]: ex = "b_consular_post"
    elif flags["e_date_only_series"]: ex = "e_date_only_series_no_geo"
    else: ex = "d_nothing"
    return flags, ex


def classifier_view(d):
    """Pre-roll view: does the app's classifier emit a geography that the index vocabulary knows,
    ignoring whether a roll covers the date? (country from a served title; consular post)."""
    geo_diplo = any(t["titleKeyServedByDiplomaticRoll"] and any(c["category"] in DIPLO | LEG and c["geoKeys"] for c in t["classifications"])
                    for t in d["classifierByTitle"])
    cons = any(c["category"] in CONS and c["geoKeys"] for c in d["classifierNoChapter"])
    return geo_diplo, cons


rep = {}
by_band = collections.defaultdict(lambda: collections.Counter())
by_vol = collections.defaultdict(lambda: collections.Counter())
gate_nothing = collections.defaultdict(collections.Counter)
shadow = collections.Counter()
shadow_examples = []
chosen_depth = collections.defaultdict(collections.Counter)
for d in docs:
    b = band_of_year(d["appYear"])
    flags, ex = outcome(d)
    for c in (by_band[b], by_vol[d["volume"]]):
        c["docs"] += 1
        c[ex] += 1
        for k, v in flags.items():
            if v: c["nonexclusive_" + k] += 1
        if d["gate"] != "ok": c["gate_" + d["gate"]] += 1
        g, cons = classifier_view(d)
        if g: c["classifier_country_served_title"] += 1
        if cons: c["classifier_consular_post"] += 1
        if d["front"]: c["front_matter_rows"] += 1
    if ex == "d_nothing":
        gate_nothing[b][d["gate"]] += 1
    if d["chosenTitleIndex"] is not None:
        chosen_depth[b][f"{d['chosenTitleIndex']}/{len(d['sectionPath'])}"] += 1
    # Shadowing: the only shown rows are date-only series, but a LATER title would have given a
    # geo-keyed diplomatic row with rolls (the loop stops at the first title producing any rolls).
    if ex == "e_date_only_series_no_geo" and d["chosenTitleIndex"] is not None:
        later = [t for i, t in enumerate(d["classifierByTitle"]) if i > d["chosenTitleIndex"]
                 and any(c["category"] in DIPLO | LEG and c.get("rollCount", 0) > 0 for c in t["classifications"])]
        if later:
            shadow[b] += 1
            if len(shadow_examples) < 8:
                shadow_examples.append({"volume": d["volume"], "d": d["d"], "header": d["header"], "dateline": d["dateline"],
                                        "path": d["sectionPath"], "shown": [r["category"] for r in d["shown"]],
                                        "lostCountryTitle": later[0]["title"]})

rep["docs_total"] = len(docs)
rep["by_band"] = {b: dict(c) for b, c in sorted(by_band.items())}
rep["d_nothing_by_gate"] = {b: dict(c) for b, c in gate_nothing.items()}
rep["chosen_title_index_over_path_len"] = {b: dict(c.most_common(12)) for b, c in chosen_depth.items()}
rep["date_only_rows_shadowing_a_country_row"] = dict(shadow)
rep["shadow_examples"] = shadow_examples

# Volume arrangement (volume band by the volume id's year)
arr = []
for vid, v in sorted(vols.items()):
    vy = vol_year(vid)
    share = v["docsUnderCountryTitle"] / v["docsInStructure"] if v["docsInStructure"] else 0.0
    c = by_vol[vid]
    arr.append({"volume": vid, "volumeYear": vy, "docsInCache": v["docsInCache"], "docsInStructure": v["docsInStructure"],
                "docsUnderCountryTitle": v["docsUnderCountryTitle"], "shareUnderCountryTitle": round(share, 4),
                "countryTitleCount": len(v["countryTitles"]),
                "a": c["a_diplomatic_country"], "b": c["b_consular_post"], "c": c["c_foreign_legation"],
                "e": c["e_date_only_series_no_geo"], "d": c["d_nothing"],
                "gate_year>=1906": c["gate_year>=1906"], "gate_noDateline": c["gate_noDateline"], "gate_noYear": c["gate_noYear"],
                "gate_noSectionPath": c["gate_noSectionPath"],
                "unmatchedTopLevelTitles": v["unmatchedTopLevelTitles"][:12]})
rep["volumes"] = arr
v1861 = [a for a in arr if 1861 <= a["volumeYear"] <= 1899]
rep["volumes_1861_1899"] = {
    "count": len(v1861),
    "with_any_country_title": sum(1 for a in v1861 if a["countryTitleCount"] > 0),
    "share_ge_0.5": sum(1 for a in v1861 if a["shareUnderCountryTitle"] >= 0.5),
    "share_ge_0.9": sum(1 for a in v1861 if a["shareUnderCountryTitle"] >= 0.9),
    "no_country_title": [a["volume"] for a in v1861 if a["countryTitleCount"] == 0],
    "share_lt_0.5": [(a["volume"], a["shareUnderCountryTitle"]) for a in v1861 if 0 < a["shareUnderCountryTitle"] < 0.5 or (a["countryTitleCount"] > 0 and a["shareUnderCountryTitle"] < 0.5)],
}
json.dump(rep, open(f"{H}/coverage.json", "w"), indent=1)
with open(f"{H}/coverage-by-volume.tsv", "w") as f:
    cols = ["volume", "volumeYear", "docsInCache", "docsInStructure", "docsUnderCountryTitle", "shareUnderCountryTitle", "countryTitleCount",
            "a", "b", "c", "e", "d", "gate_year>=1906", "gate_noDateline", "gate_noYear", "gate_noSectionPath"]
    f.write("\t".join(cols) + "\n")
    for a in arr: f.write("\t".join(str(a[k]) for k in cols) + "\n")
print(json.dumps({k: rep[k] for k in ["docs_total", "by_band", "d_nothing_by_gate", "date_only_rows_shadowing_a_country_row", "volumes_1861_1899"]}, indent=1))
