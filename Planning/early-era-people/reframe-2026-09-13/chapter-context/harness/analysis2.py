#!/usr/bin/env python3
"""Diagnostics over the harness output (stdlib). Classification fields are the Swift harness's;
the only Python-side parsing is the REPORT-ONLY city proxy in section 3, labelled as such."""
import collections, json, re, sys
H = sys.argv[1] if len(sys.argv) > 1 else "."
docs = [json.loads(l) for l in open(f"{H}/frus-pre1906-classified.jsonl")]
cov = json.load(open(f"{H}/coverage.json"))
DIPLO = {"diplomaticDespatches", "diplomaticInstructions", "notesToForeignMissions", "notesFromForeignMissions"}
band = lambda y: None if y is None else ("1861-1899" if 1861 <= y <= 1899 else "1900-1905" if 1900 <= y <= 1905 else None)
out = {}

# 1. Why nothing is shown for in-gate documents
why = {b: collections.Counter() for b in ("1861-1899", "1900-1905")}
nothing_vols = {b: collections.Counter() for b in why}
unserved_titles = collections.Counter()
for d in docs:
    b = band(d["appYear"])
    if not b or d["gate"] != "ok" or d["shown"]:
        continue
    nothing_vols[b][d["volume"]] += 1
    nc = [c["category"] for c in d["classifierNoChapter"]]
    served = [t for t in d["classifierByTitle"] if t["titleKeyServedByDiplomaticRoll"]]
    cats_any = {c["category"] for t in d["classifierByTitle"] for c in t["classifications"]}
    if served:
        # a country title exists; so no roll covered this date for the emitted category, or the
        # classifier emitted no geo-keyed category for it
        served_cats = {c["category"] for t in served for c in t["classifications"]}
        if not served_cats:
            reason = "country title in path, classifier emits nothing (e.g. Washington dateline w/o legation/department cue)"
        elif served_cats & DIPLO:
            reason = "country title in path, geo-keyed row emitted, but NO roll covers the date"
        else:
            reason = "country title in path, only date-only/consular rows emitted and none had rolls: " + ",".join(sorted(served_cats))
    else:
        if not cats_any:
            reason = "no country title in path; classifier emits nothing"
        elif cats_any <= {"diplomaticDespatches", "diplomaticInstructions", "notesToForeignMissions", "notesFromForeignMissions"}:
            reason = "no country title in path; geo-keyed row carries a non-country title key (no roll)"
        else:
            reason = "no country title in path; rows emitted: " + ",".join(sorted(cats_any))
        for t in d["classifierByTitle"]:
            unserved_titles[t["title"]] += 1
    why[b][reason] += 1
    dl = (d["dateline"] or "").lower()
    why[b]["_dateline_has_washington"] += "washington" in dl
    why[b]["_dateline_has_department_of_state"] += "department of state" in dl
out["nothing_reasons"] = {b: dict(c.most_common()) for b, c in why.items()}
out["nothing_top_volumes"] = {b: c.most_common(15) for b, c in nothing_vols.items()}
out["nothing_top_unserved_titles"] = unserved_titles.most_common(40)

# 2. Emitted-but-no-roll gaps, by category and geo key (1861-1899)
gap = collections.Counter()
for d in docs:
    if band(d["appYear"]) != "1861-1899" or d["gate"] != "ok" or d["shown"]:
        continue
    for t in d["classifierByTitle"]:
        if t["titleKeyServedByDiplomaticRoll"]:
            for c in t["classifications"]:
                gap[(c["category"], tuple(c["geoKeys"]))] += 1
out["no_roll_gaps_1861_1899"] = [[k[0], list(k[1]), n] for k, n in gap.most_common(25)]

# 3. REPORT-ONLY PROXY: U.S.-mission dateline city vs the chapter country the app chose.
# City = first comma segment after the segment holding the mission phrase. Corpus-modal country per
# city is taken over high-confidence despatch rows. A doc "disagrees" when its city's modal country
# is not the chosen country. This is an inferred proxy for "chapter country != writing post".
MISSION = ("legation of the united states", "embassy of the united states", "american legation",
           "american embassy", "united states legation", "u. s. legation", "u.s. legation")
rows = []
for d in docs:
    b = band(d["appYear"])
    if not b:
        continue
    desp = [r for r in d["shown"] if r["category"] == "diplomaticDespatches" and r["confidence"] == "high"]
    if not desp:
        continue
    segs = [s.strip() for s in (d["dateline"] or "").split(",")]
    city = None
    for i, s in enumerate(segs):
        if any(m in s.lower() for m in MISSION):
            if i + 1 < len(segs) and segs[i + 1] and not re.match(r"^[A-Za-z]+\.?\s+\d", segs[i + 1]):
                city = re.sub(r"\s+", " ", segs[i + 1]).strip(" .").lower()
            break
    if city:
        rows.append((b, d, city, desp[0]["geoKeys"][0]))
modal = collections.defaultdict(collections.Counter)
for b, d, city, ctry in rows:
    modal[city][ctry] += 1
dis = collections.Counter(); tot = collections.Counter(); ex = []; pairs = collections.Counter()
for b, d, city, ctry in rows:
    tot[b] += 1
    top, n = modal[city].most_common(1)[0]
    if top != ctry and n >= 5:
        dis[b] += 1
        pairs[(city, top, ctry)] += 1
        if len(ex) < 12:
            ex.append(f"{d['volume']}/{d['d']} | {d['header']} | {d['dateline']} | chosen={ctry} city={city} modal={top}")
out["proxy_mission_city_vs_chapter"] = {"high_conf_despatch_rows_with_city": dict(tot), "disagreeing": dict(dis),
                                         "top_pairs(city, city_modal_country, chosen_country)": [[*k, n] for k, n in pairs.most_common(20)],
                                         "examples": ex}
out["shadow_examples"] = cov["shadow_examples"]
out["chosen_title_index_over_path_len"] = cov["chosen_title_index_over_path_len"]
json.dump(out, open(f"{H}/analysis2.json", "w"), indent=1)
print(json.dumps(out, indent=1))
