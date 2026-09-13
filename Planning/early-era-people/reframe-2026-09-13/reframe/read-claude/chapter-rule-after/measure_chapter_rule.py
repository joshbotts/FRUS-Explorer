#!/usr/bin/env python3
"""What the Source Explorer chapter/dateline context DECIDES about marked from/to names (#234).

Inputs (all read-only): the Swift harness's per-document classifications
(../harness/frus-pre1906-classified.jsonl, the app's real CentralFilesClassifier), the marked
layer (~/frus-ner-raw/marked), the R-0 text layer (~/frus-semantic-raw/text), the TEI (document
years, via measure_pocom.tei_doc_years), POCOM. No classifier rule is re-implemented here: the
categories, confidences, geo keys and title keys are the Swift harness's output.

Answers compared per marked from/to row:
 (i)  POCOM surname-by-year — measure_pocom.py's surname_of/text_of/load_pocom/live_count, imported.
 (ii) chapter rule — POCOM officeholders holding a HYPOTHESISED post on the document's exact date
      whose POCOM surname equals surname_of(row).
 (iii) combination — (ii) when it names exactly one person, else (i)'s one.
Two arms of hypothesis: A = only what Source Explorer SHOWS (classification with a roll);
B = the classifier's own direction without the NARA-roll test, country from the first section
title (root->leaf) that the crosswalk maps to a POCOM territory, plus subchapter legation titles.
"""
import sys, os, re, json, gzip, random, collections, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
HARNESS = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/geo-fix/after-docs.jsonl"
MARKED = os.path.expanduser("~/frus-ner-raw")
TEXT = os.path.expanduser("~/frus-semantic-raw/text")
sys.path.insert(0, REPO + "/Planning/early-era-people/feasibility-2026-09-12/measure-pocom")
sys.path.insert(0, HERE)
import measure_pocom as MP          # surname_of, text_of, load_pocom, live_count, tei_doc_years
import ner_store                    # (imported by measure_pocom's sys.path insert)
import pocom_posts as PP

GEO_CATS = {"diplomaticDespatches", "diplomaticInstructions", "notesToForeignMissions", "notesFromForeignMissions"}
SLACK = 180


def band(vol):
    y = int(vol[4:8])
    return "1861-1899" if y <= 1899 else "1900-1905"


def parse_date(r):
    for k in ("datelineDateISO", "dateIsoIndex"):
        v = r.get(k)
        if v and re.match(r"^\d{4}-\d{2}-\d{2}$", v):
            try:
                return datetime.date(*map(int, v.split("-"))), k
            except ValueError:
                pass
    return None, None


def terr_for_key(k):
    if not k:
        return None
    if k in PP.GEO:
        return PP.GEO[k]
    rk, kind = PP.repaired_key(k)
    return PP.GEO[rk] if rk else None


def hypotheses(classifications, terr, legation_kind):
    """{'from': [alt], 'to': [alt]}; alt = ('dept',) | ('chief', terrs) | ('unc', label)."""
    H = {"from": [], "to": []}
    cats = {c["category"]: c for c in classifications}
    def add(side, alt):
        if alt not in H[side]:
            H[side].append(alt)
    chief = ("chief", terr) if terr else ("unc", "US chief of mission (country unmapped)")
    for cat, c in cats.items():
        conf = c["confidence"]
        if cat == "diplomaticDespatches":
            add("from", chief)
            add("to", ("dept",))
            if conf == "high":
                add("from", ("unc", "legation secretary / charge"))
                add("to", ("unc", "foreign official"))
            else:
                add("from", ("unc", "foreign official"))
                add("to", chief)
        elif cat == "diplomaticInstructions":
            add("from", ("dept",))
            if legation_kind != "foreign-legation":
                add("to", chief)
        elif cat == "notesToForeignMissions":
            add("from", ("dept",))
            add("to", ("unc", "foreign envoy in Washington"))
        elif cat == "notesFromForeignMissions":
            add("from", ("unc", "foreign envoy in Washington"))
            add("to", ("dept",))
        elif cat == "consularDespatches":
            post = (c.get("geoKeys") or [None])[0]
            add("from", ("unc", "US consul at post"))
            if post in PP.CONSULAR_POST_CHIEF:
                add("from", ("chief", PP.CONSULAR_POST_CHIEF[post]))
            add("to", ("dept",))
        elif cat == "notesFromForeignConsuls":
            add("from", ("unc", "foreign consul"))
            add("to", ("dept",))
        elif cat in ("notesToForeignConsuls", "consularInstructions"):
            add("from", ("dept",))
            add("to", ("unc", "consul"))
        elif cat == "lettersReceived":
            add("from", ("unc", "other US executive office"))
            add("to", ("dept",))
        elif cat == "domesticLetters":
            add("from", ("dept",))
            add("to", ("unc", "cabinet officer"))
        elif cat == "specialAgentsDespatches":
            add("from", ("unc", "special agent"))
            add("to", ("dept",))
        elif cat == "specialAgentsInstructions":
            add("from", ("dept",))
            add("to", ("unc", "special agent"))
    return H


def arm_a(r):
    shown = r["shown"]
    if not shown:
        return None
    terr = None
    for c in shown:
        if c["category"] in GEO_CATS and c["geoKeys"]:
            terr = terr_for_key(c["geoKeys"][0])
            break
    return {"classifications": shown, "terr": terr, "legation_kind": None,
            "chapter": r.get("chosenTitle"), "geo_key": next((c["geoKeys"][0] for c in shown if c["category"] in GEO_CATS and c["geoKeys"]), None)}


def arm_b(r):
    cbt = r["classifierByTitle"]
    if not cbt:
        return None
    legation_kind = None
    for t in cbt:
        rk, kind = PP.repaired_key(t["title"].lower())
        if kind in ("foreign-legation", "us-mission"):
            legation_kind = kind
    for t in cbt:
        if not t["classifications"]:
            continue
        k0 = t["titleGeoKeys"][0] if t["titleGeoKeys"] else None
        terr = PP.GEO.get(k0) if k0 else None
        via = "app-key"
        if not terr:
            rk, kind = PP.repaired_key(t["title"].lower())
            terr = PP.GEO.get(rk) if rk else None
            via = "repaired"
        if terr:
            return {"classifications": t["classifications"], "terr": terr, "legation_kind": legation_kind,
                    "chapter": t["title"], "via": via, "geo_key": k0}
    first = next((t for t in cbt if t["classifications"]), None)
    if not first:
        return None
    return {"classifications": first["classifications"], "terr": None, "legation_kind": legation_kind,
            "chapter": None, "via": None, "geo_key": None}


def main():
    random.seed(234)
    scope = [v for v in ner_store.scope_volumes(MARKED) if int(v[4:8]) <= 1905]
    surnames, spans, by_surname = MP.load_pocom()
    posts, post_stats = PP.load_posts()
    psur, pfull = PP.load_people()
    all_post_keys = list(posts.keys())

    H = {}
    for line in open(HARNESS):
        r = json.loads(line)
        if r["volume"] in scope:
            H[(r["volume"], r["d"])] = r

    def surname_match(slugs, sur):
        return {s for s in slugs if psur.get(s) == sur}

    def chapter_rule(alts, sur, date, slack=0):
        t1 = t2 = ch = set()
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

    # ------------------------------------------------------------------ accumulators
    T = collections.defaultdict(collections.Counter)      # (arm, band, grain) -> counter
    EX = collections.defaultdict(list)                     # (arm, transition) -> examples
    CW = collections.defaultdict(collections.Counter)      # crosswalk coverage
    UNMAPPED_TITLES = collections.defaultdict(collections.Counter)
    SEW = collections.Counter(); SEW_EX = collections.defaultdict(list)
    OFFICE = collections.defaultdict(collections.Counter); OFFICE_EX = collections.defaultdict(list)
    POS_CTRL = collections.defaultdict(collections.Counter)
    OTHERPOST = collections.defaultdict(collections.Counter)

    OFFICE_PATS = [
        ("acting secretary of state", re.compile(r"\bacting secretary(?: of state)?\b", re.I)),
        ("assistant secretary of state", re.compile(r"\b(?:second |third )?assistant secretary(?: of state)?\b", re.I)),
        ("secretary of state", re.compile(r"(?<!acting )(?<!assistant )\bsecretary of state\b", re.I)),
        ("minister of/for foreign affairs", re.compile(r"\bminister (?:of|for) foreign affairs\b", re.I)),
        ("foreign office", re.compile(r"\bforeign office\b", re.I)),
        ("the president", re.compile(r"\bthe president\b", re.I)),
    ]

    for vi, vol in enumerate(scope):
        b = band(vol)
        doc_years = MP.tei_doc_years(vol)
        rows = ner_store.volume_layer(MARKED, "marked", vol)
        texts = {}
        with gzip.open(os.path.join(TEXT, vol + ".jsonl.gz"), "rt", encoding="utf-8") as f:
            for line in f:
                x = json.loads(line)
                texts[x["d"]] = x["t"]
        by_doc = collections.defaultdict(list)
        for x in rows:
            by_doc[x["d"]].append(x)

        # ---- per document context
        ctx = {}
        for d, text in texts.items():
            r = H.get((vol, d))
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
            date, date_src = parse_date(r)
            ctx[d] = {"r": r, "head": (pos, pos + len(hn)) if pos >= 0 else None, "hn": hn,
                      "date": date, "date_src": date_src, "A": arm_a(r), "B": arm_b(r)}
            # crosswalk coverage, per document
            for arm in ("A", "B"):
                c = ctx[d][arm]
                if c is None:
                    CW[(arm, b)]["docs_no_classification"] += 1
                    continue
                geo = any(k["category"] in GEO_CATS for k in c["classifications"])
                if not geo:
                    CW[(arm, b)]["docs_non_geo_category"] += 1
                elif c["terr"]:
                    CW[(arm, b)]["docs_geo_mapped"] += 1
                    CW[(arm, b, "terr")][",".join(c["terr"])] += 1
                    if arm == "B":
                        CW[(arm, b, "via")][c.get("via")] += 1
                else:
                    CW[(arm, b)]["docs_geo_unmapped"] += 1
                    if arm == "A":
                        UNMAPPED_TITLES[("A-geokey", b)][c.get("geo_key")] += 1
                    else:
                        for t in r["sectionPath"]:
                            UNMAPPED_TITLES[("B-title", b)][t] += 1
                if arm == "B" and c["legation_kind"]:
                    CW[(arm, b)]["docs_with_legation_subchapter_" + c["legation_kind"]] += 1
            # office-only heads (item 4)
            if hn and r["gate"] == "ok" or hn:
                hl = hn
                marked_here = by_doc.get(d, [])
                for label, pat in OFFICE_PATS:
                    for m in pat.finditer(hl):
                        if label == "secretary of state" and re.search(r"(acting|assistant)\s+$", hl[:m.start()], re.I):
                            continue
                        OFFICE[b][label + " | head occurrences"] += 1
                        unmarked = True
                        if pos >= 0:
                            s0, e0 = pos + m.start(), pos + m.end()
                            if any(x["s"] < e0 and x["e"] > s0 for x in marked_here):
                                unmarked = False
                        else:
                            OFFICE[b][label + " | head not located in text"] += 1
                        if unmarked:
                            OFFICE[b][label + " | unmarked"] += 1
                        if date and label in ("secretary of state", "acting secretary of state", "assistant secretary of state"):
                            ks = PP.DEPT_TIER1 if label == "secretary of state" else PP.DEPT_TIER2
                            hs = set()
                            for p in ks:
                                hs |= PP.holders(posts, "dept:" + p, date)
                            if label == "secretary of state" and not hs:
                                pass
                            OFFICE[b][label + " | holders on date=%s" % (len(hs) if len(hs) < 3 else "3+")] += 1
                            if len(OFFICE_EX[(b, label)]) < 5:
                                OFFICE_EX[(b, label)].append({"doc": f"{vol}/{d}", "date": str(date), "header": " ".join(hn.split()[:14]),
                                                              "holders": sorted(pfull.get(s, s) for s in hs)})
                        elif not date:
                            OFFICE[b][label + " | no date"] += 1

        # ---- per marked row
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
            POS_CTRL[b]["n"] += 1
            POS_CTRL[b][pclass] += 1

            for arm in ("A", "B"):
                K = T[(arm, b)]
                K["rows"] += 1
                K["pocom:" + pclass] += 1
                if c is None:
                    K["no_harness_record"] += 1
                    trans = "no-hypothesis:no-harness-record"
                    K["T:" + trans] += 1
                    K["combined:" + ("pocom-one-no-hypothesis" if pclass == "one" else "undetermined")] += 1
                    continue
                grain = "enclosure"
                if c["head"] and x["s"] >= c["head"][0] and x["e"] <= c["head"][1]:
                    grain = "head"
                elif c["head"] is None and c["hn"]:
                    grain = "head-unlocated"
                elif not c["hn"]:
                    grain = "no-header"
                K["grain:" + grain] += 1
                ac = c[arm]
                alts = []
                if ac is not None and c["date"] is not None:
                    Hh = hypotheses(ac["classifications"], ac["terr"], ac["legation_kind"])
                    if grain == "head":
                        alts = Hh[x["t"]]
                    elif grain == "enclosure":
                        # non-directional: anyone the document's context names, both sides
                        for side in ("from", "to"):
                            for a in Hh[side]:
                                if a not in alts:
                                    alts.append(a)
                covered = [a for a in alts if a[0] in ("dept", "chief")]
                uncovered = [a[1] for a in alts if a[0] == "unc"]
                if not alts:
                    why = "no-classification" if ac is None else ("no-date" if c["date"] is None else "grain-" + grain)
                    trans = "no-hypothesis:" + why
                    K["T:" + trans] += 1
                    K["combined:" + ("pocom-one-no-hypothesis" if pclass == "one" else "undetermined")] += 1
                    continue
                G = T[(arm, b, grain)]
                G["rows_with_hypothesis"] += 1
                K["rows_with_hypothesis"] += 1
                if covered:
                    K["rows_with_covered_hypothesis"] += 1
                    G["rows_with_covered_hypothesis"] += 1
                for u in set(uncovered):
                    K["uncovered_alternative:" + u] += 1
                if not sur:
                    cand, tier, parts = set(), None, (set(), set(), set())
                else:
                    cand, tier, parts = chapter_rule(covered, sur, c["date"])
                n = len(cand)
                cout = {0: "zero", 1: "one"}.get(n, "several")
                mech = None
                if n == 1:
                    one = next(iter(cand))
                    if one in parts[2]:
                        mech = "chief"
                    elif one in parts[0]:
                        mech = "dept-tier1-over-same-surname-tier2" if parts[1] else "dept-tier1"
                    else:
                        mech = "dept-tier2"
                side_all_uncovered = bool(uncovered) and not covered
                G["chapter:" + cout] += 1
                K["chapter:" + cout] += 1
                if n == 1 and parts[0] and parts[1]:
                    K["chapter_one_tier1_over_same_surname_tier2"] += 1
                if n == 1 and tier == "tier2":
                    K["chapter_one_via_tier2"] += 1
                # transitions
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
                        slack_cand, _, _ = chapter_rule(covered, sur, c["date"], SLACK) if sur else (set(), None, None)
                        if not covered:
                            trans = "one:untestable-uncovered-only"
                        elif op_out:
                            trans = "one:CONTRADICTED-holder-in-other-post"
                        elif slack_cand:
                            trans = "one:CONTRADICTED-within-%dd-of-hypothesised-post" % SLACK
                        else:
                            trans = "one:CONTRADICTED-holder-in-no-post-on-date"
                        if trans.startswith("one:CONTRADICTED") and uncovered:
                            K["contradicted_but_side_has_uncovered_alternative"] += 1
                        if trans == "one:CONTRADICTED-holder-in-other-post":
                            hyp = "+".join(sorted("dept" if a[0] == "dept" else "chief:" + "/".join(a[1]) for a in covered))
                            for s_, k_ in (op_out if arm == "B" else ()):
                                OTHERPOST[(b, grain)][hyp + " -> " + k_] += 1
                elif pclass == "several":
                    trans = ("several:->one(%s)" % mech) if n == 1 else ("several:chapter-several" if n > 1 else
                                                             ("several:zero-uncovered-alternative" if uncovered else "several:zero"))
                elif pclass in ("nobody", "unknown", "undated"):
                    if n == 1:
                        trans = pclass + ":->one"
                    elif n > 1:
                        trans = pclass + ":chapter-several"
                    elif uncovered:
                        trans = pclass + ":explained-as-uncovered-role"
                    else:
                        trans = pclass + ":unexplained"
                K["T:" + trans] += 1
                G["T:" + trans] += 1
                if trans.endswith("explained-as-uncovered-role"):
                    K["explained_side_uncovered_only" if side_all_uncovered else "explained_side_mixed_covered_and_uncovered"] += 1
                    G["explained_side_uncovered_only" if side_all_uncovered else "explained_side_mixed_covered_and_uncovered"] += 1
                    for u in set(uncovered):
                        K["explained_by:%s:%s" % (pclass, u)] += 1
                if n == 1:
                    K["combined:chapter-one(" + ("corroborated" if pclass == "one" and next(iter(cand)) == pslug else "from-" + pclass) + ")"] += 1
                elif pclass == "one":
                    K["combined:pocom-one-" + trans.split(":", 1)[1]] += 1
                else:
                    K["combined:undetermined"] += 1
                # examples
                ex = {"doc": f"{vol}/{x['d']}", "date": str(c["date"]), "grain": grain, "side": x["t"], "name": x["n"],
                      "header_14w": " ".join(c["hn"].split()[:14]),
                      "chapter": ac.get("chapter"), "territory": ac.get("terr"),
                      "categories": sorted({k["category"] + "/" + k["confidence"] for k in ac["classifications"]}),
                      "pocom": pclass + ((" " + pfull.get(pslug, pslug)) if pslug else ""),
                      "chapter_rule": sorted(pfull.get(s, s) for s in cand)}
                if trans.startswith("one:CONTRADICTED"):
                    ex["holder_posts_on_date"] = sorted({k for s, k in other_post(sur, c["date"])})
                key = (arm, b, trans)
                EX[key].append(ex)

                # Seward (arm B, 1861-1869)
                if arm == "B" and sur == "Seward" and datetime.date(1861, 1, 1) <= c["date"] <= datetime.date(1869, 12, 31):
                    text = texts.get(x["d"], "")
                    sigF = bool(re.search(r"F\.\s*W\.\s*SEWARD|FREDERICK W\.\s*SEWARD", text))
                    sigW = bool(re.search(r"WILLIAM H\.\s*SEWARD|W\.\s*H\.\s*SEWARD", text))
                    sigA = bool(re.search(r"F\.\s*W\.\s*SEWARD,?\s*Acting Secretary", text))
                    sig = "F.W.-signature" if sigF and not sigW else ("W.H.-signature" if sigW and not sigF else ("both" if sigF else "neither"))
                    nameF = bool(re.search(r"\bF\.\s*W\.|Frederick", x["n"]))
                    nameW = bool(re.search(r"\bW(?:m|illiam)?\.?\s*H\.|William", x["n"]))
                    fw_in = PP.holders(posts, "dept:assistant-secretary", c["date"])
                    fw_possible = "seward-frederick-william" in fw_in and any(a[0] == "dept" for a in covered)
                    wh = "seward-william-henry" in cand and n == 1
                    k = f"{grain}|{x['t']}"
                    SEW["rows"] += 1
                    SEW["grain_side:" + k] += 1
                    SEW["dept_side_hypothesised"] += any(a[0] == "dept" for a in covered)
                    SEW["assigned_WH_Secretary"] += wh
                    SEW["assigned_other:" + ",".join(sorted(cand))] += (not wh)
                    SEW["FW_possible_by_date_and_role"] += fw_possible
                    SEW["signature:" + sig] += 1
                    SEW["sigFW_acting_in_doc"] += sigA
                    SEW["name_has_FW_initials"] += nameF
                    SEW["name_has_WH_initials"] += nameW
                    SEW["assigned_WH_but_doc_signed_FW_only | " + k] += (wh and sig == "F.W.-signature")
                    SEW["assigned_WH_and_doc_signed_WH_only | " + k] += (wh and sig == "W.H.-signature")
                    if wh and sig == "F.W.-signature" and len(SEW_EX["wh_but_fw_signed"]) < 10:
                        m = re.search(r"F\.\s*W\.\s*SEWARD[^.]{0,20}", text)
                        SEW_EX["wh_but_fw_signed"].append({"doc": f"{vol}/{x['d']}", "date": str(c["date"]), "side": x["t"], "grain": grain,
                                                           "header_14w": " ".join(c["hn"].split()[:14]), "signature": m.group(0) if m else None})
                    if nameF and len(SEW_EX["name_FW"]) < 10:
                        SEW_EX["name_FW"].append({"doc": f"{vol}/{x['d']}", "date": str(c["date"]), "name": x["n"], "grain": grain,
                                                  "chapter_rule": sorted(cand)})
        print(f"[{vi+1}/{len(scope)}] {vol}", file=sys.stderr)

    # ------------------------------------------------------------------ output
    def samp(lst, k=10):
        if len(lst) <= k:
            return lst
        return random.Random(234).sample(lst, k)

    out = {
        "generated_by": os.path.abspath(__file__),
        "scope_volumes": scope,
        "pocom_post_load_stats": dict(post_stats),
        "positive_control_pocom_classes_by_band": {b: dict(v) for b, v in POS_CTRL.items()},
        "tallies": {"|".join(k): dict(sorted(v.items())) for k, v in sorted(T.items())},
        "crosswalk": {"|".join(k): dict(v.most_common()) for k, v in sorted(CW.items())},
        "contradicted_other_post_pairs_armB": {"|".join(k): v.most_common(40) for k, v in sorted(OTHERPOST.items())},
        "unmapped": {"|".join(k): v.most_common() for k, v in sorted(UNMAPPED_TITLES.items())},
        "seward_1861_1869_armB": dict(SEW), "seward_examples": SEW_EX,
        "office_only_heads": {b: dict(sorted(v.items())) for b, v in OFFICE.items()},
        "office_examples": {"|".join(k): v for k, v in OFFICE_EX.items()},
        "examples": {"|".join(k): {"count": len(v), "sample": samp(v)} for k, v in sorted(EX.items())},
    }
    json.dump(out, open(os.path.join(HERE, "chapter-rule.json"), "w"), indent=1, sort_keys=True, default=list)
    print("wrote chapter-rule.json", file=sys.stderr)


if __name__ == "__main__":
    main()
