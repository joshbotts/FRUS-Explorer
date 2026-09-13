#!/usr/bin/env python3
"""#234 'fit' measurement: what a chapter-anchored POCOM candidate adds to the surname x year rule.

Read-only. Inputs:
  - the Swift harness's per-document output (the app's REAL classifier): ../harness/frus-pre1906-classified.jsonl
  - the marked layer ~/frus-ner-raw/marked/<vol>.jsonl.gz (from/to rows)
  - the POCOM checkout (people/, missions-countries/, positions-principals/)
surname_of, TITLES, k2_surface/HONORIFICS and the load_pocom span rule are copied from
Planning/early-era-people/feasibility-2026-09-12/measure-pocom/measure_pocom.py (itself verbatim m1a).
GEO_TO_TERRITORY is a HAND MAP from the classifier's shown geo key to POCOM contemporary-territory-id;
it is printed into the output. Agreement with the printed surname is a PROXY, not accuracy.
"""
import re, os, glob, gzip, json, collections
HERE = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.join(HERE, "..", "harness", "frus-pre1906-classified.jsonl")
MARKED = os.path.expanduser("~/frus-ner-raw/marked")
POCOM = "/Users/jbotts/Development/pocom"

TITLES = {"Mr.", "Mrs.", "Sir", "Lord", "Count", "Baron", "Prince", "King",
          "Queen", "Excellency", "Dr.", "Hon."}
def surname_of(name):
    toks = [t.strip(".,;:()") for t in name.split()]
    toks = [t for t in toks if t and t not in TITLES and t[0].isupper() and len(t) >= 3]
    return toks[-1] if toks else None
HONORIFICS = {"mr","mrs","miss","ms","dr","sir","lord","lady","count","countess","baron","baroness","prince",
 "princess","king","queen","excellency","hon","gen","general","col","colonel","capt","captain","maj","major",
 "lieut","lt","lieutenant","adm","admiral","commodore","rev","reverend","don","dona","doña","señor","senor",
 "señora","monsieur","m","mme","madame","mlle","herr","earl","duke","marquis","viscount","president",
 "secretary","ambassador","minister","governor","judge","prof","professor","the","his","her","majesty"}
POSSESSIVE = re.compile(r"(?:'|’)s$")
def k2_surface(raw):
    s = " ".join(raw.split()); s = POSSESSIVE.sub("", s).strip(); toks = s.split()
    while toks and toks[0].strip(".,").casefold() in HONORIFICS: toks = toks[1:]
    s = " ".join(toks); return s.casefold(), s

GEO_TO_TERRITORY = {
 "great britain":["united-kingdom"], "spain":["spain"], "china":["china"], "mexico":["mexico"],
 "france":["france"], "turkey":["turkey"], "russia":["russia"], "germany":["germany"], "prussia":["germany"],
 "japan":["japan"], "haiti":["haiti"], "austria":["austria"], "colombia":["colombia"],
 "venezuela":["venezuela"], "brazil":["brazil"],
 "central america":["guatemala","costa-rica","el-salvador","honduras","nicaragua"],
 "peru":["peru"], "belgium":["belgium"], "italy":["italy"], "switzerland":["switzerland"],
 "netherlands":["netherlands"], "denmark":["denmark"], "portugal":["portugal"], "chile":["chile"],
 "sweden":["sweden"], "hawaii":["hawaii"], "persia":["iran"], "ecuador":["ecuador"],
 "dominican republic":["dominican-republic"], "paraguay":["paraguay"], "korea":["joseon-dynasty-1910"],
 "greece":["greece"], "bolivia":["bolivia"], "argentina":["argentina"], "liberia":["liberia"],
 "siam":["thailand"], "uruguay":["uruguay"], "rumania":["romania"], "serbia":["serbia"],
 "costa rica":["costa-rica"], "nicaragua":["nicaragua"], "el salvador":["el-salvador"],
 "honduras":["honduras"], "egypt":["egypt"],
}

def load():
    surnames = {}
    for p in sorted(glob.glob(f"{POCOM}/people/*/*.xml")):
        t = open(p, encoding="utf-8", errors="replace").read()
        sid = re.search(r"<id>([^<]+)</id>", t); sur = re.search(r"<surname>([^<]*)</surname>", t)
        if sid and sur and sur.group(1).strip(): surnames[sid.group(1)] = sur.group(1).strip()
    spans = collections.defaultdict(list)          # slug -> spans (any appointment): the surname rule
    chiefs = collections.defaultdict(list)         # territory -> [(slug, lo, hi, role)]
    principals = collections.defaultdict(list)     # position file -> [(slug, lo, hi)]
    for p in sorted(glob.glob(f"{POCOM}/missions-*/*.xml")) + sorted(glob.glob(f"{POCOM}/positions-principals/*.xml")):
        t = open(p, encoding="utf-8", errors="replace").read()
        for blk in re.findall(r"<(?:chief|principal)>.*?</(?:chief|principal)>", t, re.S):
            pid = re.search(r"<person-id>([^<]+)</person-id>", blk)
            if not pid: continue
            ys = [int(y) for y in re.findall(r"<date>(\d{4})", blk)]
            if not ys: continue
            lo, hi = min(ys), max(ys); spans[pid.group(1)].append((lo, hi))
            if "/missions-countries/" in p:
                ct = re.search(r"<contemporary-territory-id>([^<]*)<", blk)
                role = re.search(r"<role-title-id>([^<]*)<", blk)
                chiefs[ct.group(1) if ct else os.path.basename(p)[:-4]].append((pid.group(1), lo, hi, role.group(1) if role else ""))
            elif "/positions-principals/" in p:
                principals[os.path.basename(p)[:-4]].append((pid.group(1), lo, hi))
    by_surname = collections.defaultdict(set)
    for slug, sur in surnames.items():
        if slug in spans: by_surname[sur].add(slug)
    return surnames, spans, chiefs, principals, by_surname

def in_office(lo, hi, y, w): return lo - w <= y <= hi + w

def main():
    surnames, spans, chiefs, principals, by_surname = load()
    docs = {}
    for l in open(HARNESS):
        r = json.loads(l)
        if r["gate"] != "ok" or r["appYear"] is None or not (1861 <= r["appYear"] <= 1899): continue
        docs[(r["volume"], r["d"])] = r
    vols = sorted({v for v, _ in docs})
    out = {"inputs": {"harness": HARNESS, "docs_1861_1899_in_gate": len(docs), "volumes": len(vols),
                      "geo_to_territory_hand_map": GEO_TO_TERRITORY}, "by_window": {}}
    examples = collections.defaultdict(list)
    GRAIN = os.environ.get("GRAIN", "all")
    out["inputs"]["grain"] = GRAIN
    for W in (0, 1):
        tally = collections.defaultdict(collections.Counter)
        cross = collections.defaultdict(collections.Counter)
        marked_vols = 0; rows_total = 0
        for v in vols:
            path = f"{MARKED}/{v}.jsonl.gz"
            if not os.path.exists(path): continue
            marked_vols += 1
            allrows = [json.loads(x) for x in gzip.open(path, "rt")]
            if GRAIN == "head":
                first = {}
                for rr in allrows:
                    if rr["t"] in ("from", "to"):
                        k_ = (rr["d"], rr["t"])
                        if k_ not in first or rr["s"] < first[k_]["s"]: first[k_] = rr
                allrows = sorted(first.values(), key=lambda rr: (rr["d"], rr["s"]))
            for row in allrows:
                if row["t"] not in ("from", "to"): continue
                r = docs.get((v, row["d"]))
                if r is None: continue
                rows_total += 1
                y = r["appYear"]
                shown = r["shown"]
                cats = sorted({s["category"] for s in shown})
                conf = sorted({s["confidence"] for s in shown})
                geo = next((s["geoKeys"][0] for s in shown if s.get("geoKeys")), None)
                if not shown: kind = "nothing"
                elif cats == ["diplomaticDespatches"]: kind = "despatch-" + conf[0]
                elif "diplomaticInstructions" in cats and "notesToForeignMissions" in cats: kind = "instr+notesTo"
                elif cats == ["notesFromForeignMissions"]: kind = "notesFrom"
                elif cats == ["diplomaticInstructions"]: kind = "instructions"
                elif cats == ["notesToForeignMissions"]: kind = "notesTo"
                elif cats == ["consularDespatches"]: kind = "consular"
                else: kind = "other"
                key = f"{kind}|{row['t']}"
                _, stripped = k2_surface(row["n"]); sur = surname_of(stripped)
                # surname x year rule (the assessment's)
                base_live = set()
                if sur is None: base = "no-surname"
                elif sur not in by_surname: base = "unknown"
                else:
                    live = {s for s in by_surname[sur] if any(in_office(lo, hi, y, W) for lo, hi in spans[s])}
                    base = "one" if len(live) == 1 else ("several" if live else "nobody")
                    base_live = live
                # chapter x year rule
                terrs = GEO_TO_TERRITORY.get(geo) if geo else None
                if terrs is None:
                    chap = "no-territory" if kind != "nothing" else "nothing-shown"
                    cset = set()
                else:
                    cset = {c[0] for t_ in terrs for c in chiefs.get(t_, []) if in_office(c[1], c[2], y, W)}
                    if not cset: chap = "no-chief-in-office"
                    elif sur is None: chap = f"chiefs{min(len(cset),2)}-no-surname"
                    else:
                        agree = {s for s in cset if surnames.get(s) == sur}
                        n = "1" if len(cset) == 1 else "2+"
                        chap = f"chiefs{n}-" + ("agree-unique" if len(agree) == 1 else ("agree-multi" if agree else "disagree"))
                        if len(agree) == 1 and base == "one":
                            tally[key]["slug:" + ("same-as-surname-rule" if agree == base_live else "DIFFERENT-from-surname-rule")] += 1
                        if len(agree) == 1 and base == "several":
                            tally[key]["slug:several-resolved-to-one"] += 1
                # Secretary of State for Department-originated FROM
                sec = None
                if kind in ("instr+notesTo", "instructions", "notesTo") and row["t"] == "from" and sur:
                    secs = {p[0] for p in principals.get("secretary", []) if in_office(p[1], p[2], y, W)}
                    asst = {p[0] for f in ("assistant-secretary", "assistant-secretary2", "second-assistant-secretary", "third-assistant-secretary")
                            for p in principals.get(f, []) if in_office(p[1], p[2], y, W)}
                    sec_agree = {s for s in secs if surnames.get(s) == sur}
                    asst_agree = {s for s in asst if surnames.get(s) == sur}
                    sec = ("sec-agree" if sec_agree else "sec-disagree") + ("+asst-same-surname" if asst_agree else "")
                    tally[key + "|secstate"][sec] += 1
                tally[key]["rows"] += 1
                tally[key]["chapter:" + chap] += 1
                tally[key]["surname:" + base] += 1
                cross[key][f"{chap} x {base}"] += 1
                if W == 1 and chap.startswith("chiefs") and "agree-unique" in chap and base != "one" and len(examples[key]) < 4:
                    examples[key].append({"vol": v, "d": row["d"], "year": y, "name": row["n"], "geo": geo,
                                          "chiefs": sorted(cset), "surname_rule": base})
                if W == 1 and chap.endswith("disagree") and len(examples[key + "|disagree"]) < 4:
                    examples[key + "|disagree"].append({"vol": v, "d": row["d"], "year": y, "name": row["n"],
                                                        "geo": geo, "chiefs": sorted(cset), "header": r["header"][:90]})
        out["by_window"][f"pm{W}"] = {"marked_volumes": marked_vols, "fromto_rows_in_1861_1899_docs": rows_total,
                                      "tally": {k: dict(c) for k, c in sorted(tally.items())},
                                      "cross": {k: dict(c.most_common()) for k, c in sorted(cross.items())}}
    out["examples_pm1"] = examples
    json.dump(out, open(os.path.join(HERE, f"chapter_candidates-{GRAIN}.json"), "w"), indent=1, ensure_ascii=False)
    # compact summary
    for W in ("pm0", "pm1"):
        b = out["by_window"][W]; print("==", W, "rows", b["fromto_rows_in_1861_1899_docs"], "marked vols", b["marked_volumes"])
        for k, c in b["tally"].items():
            if "|secstate" in k: print("  ", k, c); continue
            print("  ", k, c["rows"], {x: y for x, y in sorted(c.items()) if x != "rows"})
main()
