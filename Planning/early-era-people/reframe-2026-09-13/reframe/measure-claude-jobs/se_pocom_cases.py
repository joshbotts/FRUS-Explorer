#!/usr/bin/env python3
"""measure-claude-jobs/se_pocom_cases.py — per-case INPUT sizes for job C (Source Explorer x POCOM adjudication)
and for the 100-row pre-1910 identity pilot (job E), #234 reframe.

The row classification is chapter-context/coverage/measure_chapter_rule.py's own: its hypotheses / arm_a / arm_b /
parse_date are IMPORTED, and its per-row transition logic (lines 316-420 of that file) is repeated below with only the
examples, office and Seward-signature side tallies removed, so the class counts must reproduce its
chapter-rule.json / summary.json. That reproduction is the positive control, and is printed.

A case's payload is a plain-text block: case id + side + name, date, header, dateline, chapter path (sectionPath),
classifier categories/confidence/geoKeys + mapped POCOM territory, then one career line per candidate officeholder.
Candidates = POCOM same-surname officeholders live in the document year ±1 (measure_pocom's rule) UNION the holders,
on the document's date, of every post the chapter hypothesis names (Department tier 1+2; chief of the territory).
Career line = measure_pocom_payload_v2.py's description: 'Forename Surname [slug] (birth–death)' + each appointment
'Role, Territory, YYYY–YYYY', restricted to the volume's manifest window ±1 (chars) and unrestricted (chars_all).

Env: HARNESS (default the pre-#1292 harness output), LABEL (output suffix). Read-only. Stdlib only.
"""
import sys
sys.dont_write_bytecode = True
import os, re, json, gzip, glob, csv, collections

HERE = os.path.dirname(os.path.abspath(__file__))
SP = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad"
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, SP + "/chapter-context/coverage")
import measure_chapter_rule as M   # noqa: E402  (imports measure_pocom, ner_store, pocom_posts)
MP, PP, ner_store = M.MP, M.PP, M.ner_store
HARNESS = os.environ.get("HARNESS", SP + "/chapter-context/harness/frus-pre1906-classified.jsonl")
LABEL = os.environ.get("LABEL", "pre1292")
POCOM = "/Users/jbotts/Development/pocom"
IDCSV = REPO + "/Planning/early-era-people/m1a-eval-candidates.csv"


def collapse(s):
    return " ".join(s.split())


def humanize(slug):
    return re.sub(r"-\d{4}$", "", slug or "").replace("-", " ").title()


# ---- career-line vocabulary: verbatim logic from llm-pass/cost-scale/measure_pocom_payload_v2.py
labels = {}
for p in glob.glob(POCOM + "/roles-country-chiefs/*.xml") + glob.glob(POCOM + "/positions-principals/*.xml"):
    t = open(p, encoding="utf-8", errors="replace").read()
    i = re.search(r"<id>([^<]+)</id>", t); s = re.search(r"<singular>(.*?)</singular>", t, re.S)
    if i and s:
        labels[i.group(1)] = collapse(s.group(1))
people = {}
for p in sorted(glob.glob(POCOM + "/people/*/*.xml")):
    t = open(p, encoding="utf-8", errors="replace").read()
    sid = re.search(r"<id>([^<]+)</id>", t); sur = re.search(r"<surname>([^<]*)</surname>", t)
    fore = re.search(r"<forename>([^<]*)</forename>", t); gen = re.search(r"<genname>([^<]*)</genname>", t)
    b = re.search(r"<birth>([^<]*)</birth>", t); d = re.search(r"<death>([^<]*)</death>", t)
    if sid:
        people[sid.group(1)] = dict(sur=(sur.group(1).strip() if sur else ""), fore=(fore.group(1).strip() if fore else ""),
                                    gen=(gen.group(1).strip() if gen else ""), birth=(b.group(1) if b else ""), death=(d.group(1) if d else ""))
appts = collections.defaultdict(list)
for path in sorted(glob.glob(POCOM + "/missions-*/*.xml")) + sorted(glob.glob(POCOM + "/positions-principals/*.xml")):
    t = open(path, encoding="utf-8", errors="replace").read()
    place = re.search(r"<territory-id>([^<]+)</territory-id>", t) or re.search(r"<id>([^<]+)</id>", t)
    for blk in re.findall(r"<(?:chief|principal)>.*?</(?:chief|principal)>", t, re.S):
        pid = re.search(r"<person-id>([^<]+)</person-id>", blk)
        if not pid:
            continue
        years = [int(y) for y in re.findall(r"<date>(\d{4})", blk)]
        if not years:
            continue
        role = re.search(r"<role-title-id>([^<]+)</role-title-id>", blk)
        rid = role.group(1) if role else ""
        where = "" if "positions-principals" in path else ", " + humanize(place.group(1) if place else "")
        appts[pid.group(1)].append((min(years), max(years), "%s%s, %d–%d" % (labels.get(rid, humanize(rid)), where, min(years), max(years))))


def career(slug, lo, hi, whole=False):
    pe = people.get(slug, dict(sur=slug, fore="", gen="", birth="", death=""))
    h = "%s [%s] (%s–%s)" % (collapse("%s %s %s" % (pe["fore"], pe["sur"], pe["gen"])), slug, pe["birth"], pe["death"])
    ap = [x for a, b, x in appts.get(slug, ()) if whole or (a - 1 <= hi and lo <= b + 1)]
    return h + " " + "; ".join(ap)


def stats(xs):
    xs = sorted(xs)
    if not xs:
        return {"n": 0}
    q = lambda f: xs[min(len(xs) - 1, int(f * len(xs)))]
    return {"n": len(xs), "sum": sum(xs), "mean": round(sum(xs) / len(xs), 1), "p50": q(0.5), "p90": q(0.9), "p99": q(0.99), "max": xs[-1]}


def main():
    scope = [v for v in ner_store.scope_volumes(M.MARKED) if int(v[4:8]) <= 1905]
    surnames, spans, by_surname = MP.load_pocom()
    posts, _ = PP.load_posts()
    psur, pfull = PP.load_people()
    all_post_keys = list(posts.keys())
    windows = MP.load_windows()
    Hd = {}
    for line in open(HARNESS):
        r = json.loads(line)
        if r["volume"] in scope:
            Hd[(r["volume"], r["d"])] = r
    idrows = [x for x in csv.DictReader(open(IDCSV)) if int(x["year"]) < 1910]
    idkeys = collections.Counter((x["volume"], x["document"], x["role"], x["surname"]) for x in idrows)

    def surname_match(slugs, sur):
        return {s for s in slugs if psur.get(s) == sur}

    def chapter_rule(alts, sur, date, slack=0):
        t1, t2, ch = set(), set(), set()
        for a in alts:
            if a[0] == "dept":
                for p in PP.DEPT_TIER1:
                    t1 |= PP.holders(posts, "dept:" + p, date, slack)
                for p in PP.DEPT_TIER2:
                    t2 |= PP.holders(posts, "dept:" + p, date, slack)
            elif a[0] == "chief":
                for terr in a[1]:
                    ch |= PP.holders(posts, "chief:" + terr, date, slack)
        m1, m2, mc = surname_match(t1, sur), surname_match(t2, sur), surname_match(ch, sur)
        cand = (m1 | mc) if (m1 or mc) else m2
        tier = "tier1/chief" if (m1 or mc) else ("tier2" if m2 else None)
        return cand, tier, (m1, m2 - m1, mc)

    def other_post(sur, date):
        out = set()
        for k in all_post_keys:
            for s in surname_match(PP.holders(posts, k, date), sur):
                out.add((s, k))
        return out

    def payload(vol, d, r, hn, date, x, ac, covered, sur, ty):
        lo, hi = windows[vol]
        cands = set()
        if sur and by_surname.get(sur) and ty is not None:
            cands = {s for s in by_surname[sur] if any(a - 1 <= ty <= bb + 1 for a, bb in spans[s])}
        hyp = set()
        if date is not None:
            for a in covered:
                if a[0] == "dept":
                    for p in PP.DEPT_TIER1 + PP.DEPT_TIER2:
                        hyp |= PP.holders(posts, "dept:" + p, date)
                elif a[0] == "chief":
                    for terr in a[1]:
                        hyp |= PP.holders(posts, "chief:" + terr, date)
        allc = sorted(cands | hyp)
        cats = "; ".join(sorted({k["category"] + "/" + k["confidence"] + "[" + ",".join(k.get("geoKeys") or []) + "]"
                                 for k in (ac["classifications"] if ac else [])}))
        head = ["case %s/%s %s: %s" % (vol, d, x["t"], x["n"]), "date: %s" % (date if date is not None else ty),
                "header: " + (hn or ""), "dateline: " + collapse((r or {}).get("dateline") or ""),
                "chapter: " + " > ".join((r or {}).get("sectionPath") or []),
                "classifier: %s; territory: %s" % (cats or "none", ",".join(ac["terr"]) if ac and ac.get("terr") else "none")]
        a = "\n".join(head + ["candidate: " + career(s, lo, hi) for s in allc])
        b = "\n".join(head + ["candidate: " + career(s, lo, hi, True) for s in allc])
        return len(a), len(b), len(allc), len(cands), len(hyp), len("\n".join(head))

    T = collections.defaultdict(collections.Counter)
    SZ = collections.defaultdict(lambda: collections.defaultdict(list))   # (arm, band, cls) -> field -> values
    SEWARD = collections.Counter()
    IDP = collections.defaultdict(list)
    idseen = collections.Counter()
    for vi, vol in enumerate(scope):
        b = M.band(vol)
        doc_years = MP.tei_doc_years(vol)
        rows = ner_store.volume_layer(M.MARKED, "marked", vol)
        texts = {}
        with gzip.open(os.path.join(M.TEXT, vol + ".jsonl.gz"), "rt", encoding="utf-8") as f:
            for line in f:
                j = json.loads(line)
                texts[j["d"]] = j["t"]
        ctx = {}
        for d, text in texts.items():
            r = Hd.get((vol, d))
            if r is None:
                ctx[d] = None
                continue
            hn = " ".join((r.get("header") or "").split())
            pos = -1
            if hn:
                pos = text.find(hn, 0, 80 + len(hn))
                if pos < 0:
                    hn2 = hn.replace("&", "&amp;")
                    pos = text.find(hn2, 0, 80 + len(hn2))
                    if pos >= 0:
                        hn = hn2
            date, _ = M.parse_date(r)
            ctx[d] = {"r": r, "head": (pos, pos + len(hn)) if pos >= 0 else None, "hn": hn, "date": date, "A": M.arm_a(r), "B": M.arm_b(r)}
        for x in rows:
            if x["t"] not in ("from", "to"):
                continue
            c = ctx.get(x["d"])
            sur = MP.surname_of(MP.text_of(x["n"]))
            cands = by_surname.get(sur) if sur else None
            ty = doc_years.get(x["d"])
            if not cands:
                pclass, pslug = "unknown", None
            elif ty is None:
                pclass, pslug = "undated", None
            else:
                live = [s for s in cands if any(a - 1 <= ty <= bb + 1 for a, bb in spans[s])]
                pclass = {0: "nobody", 1: "one"}.get(len(live), "several")
                pslug = live[0] if len(live) == 1 else None
            idk = (vol, x["d"], x["t"], sur)
            for arm in ("A", "B"):
                K = T[(arm, b)]
                K["rows"] += 1
                K["pocom:" + pclass] += 1
                want_id = idk in idkeys and idseen[(arm,) + idk] < idkeys[idk]
                if c is None:
                    if pclass == "several":
                        SZ[(arm, b, "several_no_hypothesis")]["n"].append(1)
                    if want_id:
                        idseen[(arm,) + idk] += 1
                        IDP[arm].append({"row": "/".join(map(str, idk)), "harness": False, "payload": None,
                                         "doc_chars": len(texts.get(x["d"], ""))})
                    continue
                grain = "enclosure"
                if c["head"] and x["s"] >= c["head"][0] and x["e"] <= c["head"][1]:
                    grain = "head"
                elif c["head"] is None and c["hn"]:
                    grain = "head-unlocated"
                elif not c["hn"]:
                    grain = "no-header"
                ac = c[arm]
                alts = []
                if ac is not None and c["date"] is not None:
                    Hh = M.hypotheses(ac["classifications"], ac["terr"], ac["legation_kind"])
                    if grain == "head":
                        alts = Hh[x["t"]]
                    elif grain == "enclosure":
                        for side in ("from", "to"):
                            for a in Hh[side]:
                                if a not in alts:
                                    alts.append(a)
                covered = [a for a in alts if a[0] in ("dept", "chief")]
                uncovered = [a[1] for a in alts if a[0] == "unc"]
                if want_id:
                    idseen[(arm,) + idk] += 1
                    pl = payload(vol, x["d"], c["r"], c["hn"], c["date"], x, ac, covered, sur, ty)
                    IDP[arm].append({"row": "/".join(map(str, idk)), "harness": True, "grain": grain, "has_hypothesis": bool(alts),
                                     "payload_chars": pl[0], "payload_chars_all_appts": pl[1], "candidates": pl[2],
                                     "doc_chars": len(texts.get(x["d"], ""))})
                if not alts:
                    if pclass == "several":
                        pl = payload(vol, x["d"], c["r"], c["hn"], c["date"], x, ac, covered, sur, ty)
                        S = SZ[(arm, b, "several_no_hypothesis")]
                        for k, val in zip(("chars", "chars_all", "cands", "surname_cands", "hyp_holders", "context_chars"), pl):
                            S[k].append(val)
                        S["n"].append(1); S["doc8k"].append(min(8000, len(texts.get(x["d"], "")))); S["doc20k"].append(min(20000, len(texts.get(x["d"], "")))); S["grain_head"].append(1 if grain == "head" else 0)
                    continue
                K["rows_with_hypothesis"] += 1
                if not sur:
                    cand, tier, parts = set(), None, (set(), set(), set())
                else:
                    cand, tier, parts = chapter_rule(covered, sur, c["date"])
                n = len(cand)
                mech = None
                if n == 1:
                    one = next(iter(cand))
                    if one in parts[2]:
                        mech = "chief"
                    elif one in parts[0]:
                        mech = "dept-tier1-over-same-surname-tier2" if parts[1] else "dept-tier1"
                    else:
                        mech = "dept-tier2"
                trans = None
                if pclass == "one":
                    if n == 1:
                        trans = ("one:corroborated(%s)" % mech) if next(iter(cand)) == pslug else "one:chapter-names-another"
                    elif n > 1:
                        trans = "one:chapter-several"
                    else:
                        op = other_post(sur, c["date"]) if sur else set()
                        hyp_keys = set()
                        for a in covered:
                            if a[0] == "dept":
                                hyp_keys |= {"dept:" + p for p in PP.DEPT_TIER1 + PP.DEPT_TIER2}
                            else:
                                hyp_keys |= {"chief:" + t for t in a[1]}
                        op_out = {(s, k) for s, k in op if k not in hyp_keys}
                        slack_cand, _, _ = chapter_rule(covered, sur, c["date"], M.SLACK) if sur else (set(), None, None)
                        if not covered:
                            trans = "one:untestable-uncovered-only"
                        elif op_out:
                            trans = "one:CONTRADICTED-holder-in-other-post"
                        elif slack_cand:
                            trans = "one:CONTRADICTED-within-%dd-of-hypothesised-post" % M.SLACK
                        else:
                            trans = "one:CONTRADICTED-holder-in-no-post-on-date"
                elif pclass == "several":
                    trans = ("several:->one(%s)" % mech) if n == 1 else ("several:chapter-several" if n > 1 else
                                                                         ("several:zero-uncovered-alternative" if uncovered else "several:zero"))
                if trans is None:
                    continue
                K["T:" + trans] += 1
                if trans.startswith("one:CONTRADICTED"):
                    cls = "contradicted"
                elif trans == "several:->one(dept-tier1-over-same-surname-tier2)":
                    cls = "seward_assumption"
                    SEWARD[(arm, b, "surname=" + ("Seward" if sur == "Seward" else "other"))] += 1
                    if sur != "Seward":
                        SEWARD[(arm, b, "other:" + str(sur))] += 1
                elif trans.startswith("several:->one"):
                    cls = "several_narrowed_by_location"
                elif trans.startswith("several:"):
                    cls = "several_unresolved"
                else:
                    continue
                pl = payload(vol, x["d"], c["r"], c["hn"], c["date"], x, ac, covered, sur, ty)
                S = SZ[(arm, b, cls)]
                for k, val in zip(("chars", "chars_all", "cands", "surname_cands", "hyp_holders", "context_chars"), pl):
                    S[k].append(val)
                S["n"].append(1); S["doc8k"].append(min(8000, len(texts.get(x["d"], "")))); S["doc20k"].append(min(20000, len(texts.get(x["d"], "")))); S["grain_head"].append(1 if grain == "head" else 0)
        print("[%d/%d] %s" % (vi + 1, len(scope), vol), file=sys.stderr)

    summ = json.load(open(SP + "/chapter-context/coverage/summary.json"))
    expect = {(s["arm"], s["band"]): s for s in summ}
    control = {}
    for (arm, b), K in sorted(T.items()):
        got = {"one_contradicted": sum(v for k, v in K.items() if k.startswith("T:one:CONTRADICTED")),
               "several_to_one": sum(v for k, v in K.items() if k.startswith("T:several:->one")),
               "several_to_one_by_secretary_over_same_surname_assistant": K.get("T:several:->one(dept-tier1-over-same-surname-tier2)", 0),
               "rows": K["rows"], "rows_with_hypothesis": K["rows_with_hypothesis"], "pocom_several": K.get("pocom:several", 0)}
        e = expect.get((arm, b), {})
        control["%s|%s" % (arm, b)] = {"measured": got, "summary_json": {k: e.get(k) for k in got if k in e},
                                       "match": all(got[k] == e[k] for k in got if k in e)}
    out = {"generated_by": os.path.abspath(__file__), "harness": HARNESS, "label": LABEL,
           "positive_control_vs_summary_json": control,
           "classes": {"|".join(k): {f: (stats(v) if f != "n" else len(v)) for f, v in S.items()} for k, S in sorted(SZ.items())},
           "seward_assumption_surnames": {"|".join(k): v for k, v in sorted(SEWARD.items())},
           "identity_pilot_rows_requested": len(idrows),
           "identity_pilot": {arm: {"matched_rows": len(v), "with_harness": sum(1 for r in v if r["harness"]),
                                    "with_hypothesis": sum(1 for r in v if r.get("has_hypothesis")),
                                    "payload_chars": stats([r["payload_chars"] for r in v if r.get("payload_chars") is not None]),
                                    "payload_chars_all_appts": stats([r["payload_chars_all_appts"] for r in v if r.get("payload_chars_all_appts") is not None]),
                                    "candidates": stats([r["candidates"] for r in v if r.get("candidates") is not None]),
                                    "doc_chars": stats([r["doc_chars"] for r in v]),
                                    "doc_chars_capped_8000": sum(min(8000, r["doc_chars"]) for r in v),
                                    "doc_chars_capped_20000": sum(min(20000, r["doc_chars"]) for r in v),
                                    "rows": v} for arm, v in IDP.items()}}
    json.dump(out, open(os.path.join(HERE, "se-pocom-cases-%s.json" % LABEL), "w"), indent=1, sort_keys=True)
    print(json.dumps(control, indent=1))
    print(json.dumps({k: {"n": v["n"], "chars": v.get("chars")} for k, v in out["classes"].items()}, indent=1))


if __name__ == "__main__":
    main()
