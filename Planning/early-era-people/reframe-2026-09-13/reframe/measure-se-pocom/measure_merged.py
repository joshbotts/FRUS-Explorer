#!/usr/bin/env python3
"""#234 reframe -- does Source Explorer's chapter-derived post corroborate POCOM's surname-by-year pick?
Re-run on the MERGED classifier (PR #1292, HEAD f63e253e) beside the pre-#1292 run.

Inputs, all read-only: lib_se.BEFORE / lib_se.AFTER (the compiled classifier's per-document output over the
46,837-document live-index export; AFTER is md5-identical to classified/head-docs.jsonl rebuilt here from HEAD),
the marked layer (~/frus-ner-raw/marked, TEI-rule scope), the R-0 text layer (~/frus-semantic-raw/text),
the TEI (document years via measure_pocom.tei_doc_years) and the POCOM checkout.

Every decision rule is imported unchanged from the earlier coverage run (lib/measure_chapter_rule.py:
hypotheses, arm_a, arm_b, parse_date; lib/pocom_posts.py; lib/measure_pocom.py), and the tally formulas are
summarize.py's. Arms:
  A0        control: earlier arm A (shown) over BEFORE; must reproduce chapter-context/coverage/summary.json
  B0        control: earlier arm B (title candidates + Python title repairs) over BEFORE; must reproduce it too
  S_before  shown, GEO crosswalk only, BEFORE          S_after  the same over AFTER (what Source Explorer shows now)
  T_before  candidates without the roll test, app keys only (no Python repair), BEFORE
  T_after   the same over AFTER: the merged-classifier analogue of B0
  B_after   B0's Python approximation applied over AFTER (isolates classifier changes from title repairs)
Writes out/merged-rule.json, out/tables.txt, out/rows.jsonl.gz.
"""
import os, sys, re, json, gzip, collections, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib_se as S
import measure_pocom as MP
import measure_chapter_rule as M
import ner_store

PP = S.PP
TEXT = os.path.expanduser("~/frus-semantic-raw/text")
OUT = os.path.join(HERE, "out")
EARLIER_SUMMARY = os.path.join(S.SP, "chapter-context", "coverage", "summary.json")
SLACK = 180
ARMS = ["A0", "B0", "S_before", "S_after", "T_before", "T_after", "B_after"]
LABEL_ARMS = ["S_before", "S_after", "T_before", "T_after"]
SIG = re.compile(r"(F\.\s*W\.\s*SEWARD|FREDERICK W\.\s*SEWARD|WILLIAM H\.\s*SEWARD|W\.\s*H\.\s*SEWARD)")
HUNTER_LO, HUNTER_HI = datetime.date(1865, 1, 1), datetime.date(1866, 7, 26)
WH, FW = "seward-william-henry", "seward-frederick-william"


def arm_ctx(arm, rb, ra):
    return {"A0": lambda: M.arm_a(rb), "B0": lambda: M.arm_b(rb), "S_before": lambda: S.arm_S(rb),
            "S_after": lambda: S.arm_S(ra), "T_before": lambda: S.arm_T(rb), "T_after": lambda: S.arm_T(ra),
            "B_after": lambda: M.arm_b(ra)}[arm]()


def short(t):
    if t.startswith("one:corroborated"):
        return "one:corroborated"
    if t.startswith("one:CONTRADICTED"):
        return "one:contradicted"
    if t == "several:->one(dept-tier1-over-same-surname-tier2)":
        return "several:->one(convention)"
    if t.startswith("several:->one"):
        return "several:->one(location)"
    if t.startswith("no-hypothesis"):
        return "no-hypothesis"
    return t


def summarize(t):
    g = lambda k: t.get(k, 0)
    n = g("rows"); one = g("pocom:one")
    corr = sum(v for k, v in t.items() if k.startswith("T:one:corroborated"))
    s2o = sum(v for k, v in t.items() if k.startswith("T:several:->one"))
    conv = g("T:several:->one(dept-tier1-over-same-surname-tier2)")
    contra = sum(v for k, v in t.items() if k.startswith("T:one:CONTRADICTED"))
    chap_one = g("chapter:one")
    pocom_only = one - corr
    lenient = chap_one + pocom_only
    strict = chap_one + pocom_only - contra
    expl = sum(v for k, v in t.items() if k.endswith("explained-as-uncovered-role"))
    r = lambda a, b: round(a / b, 4) if b else None
    return dict(rows=n, rows_with_hypothesis=g("rows_with_hypothesis"),
                rows_with_covered_hypothesis=g("rows_with_covered_hypothesis"),
                i_pocom_one=one, i_share=r(one, n), chapter_one=chap_one, chapter_share=r(chap_one, n),
                one_corroborated=corr, one_corroborated_share_of_pocom_one=r(corr, one),
                several_to_one=s2o, several_to_one_by_secretary_over_same_surname_assistant=conv,
                several_to_one_other=s2o - conv, one_contradicted=contra,
                one_untestable_uncovered_only=g("T:one:untestable-uncovered-only"),
                one_no_hypothesis=g("combined:pocom-one-no-hypothesis"),
                nobody_or_unknown_explained_uncovered=expl,
                explained_side_uncovered_only=g("explained_side_uncovered_only"),
                iii_lenient=lenient, iii_lenient_share=r(lenient, n),
                iii_strict_veto_contradicted=strict, iii_strict_share=r(strict, n),
                iii_strict_without_convention=strict - conv,
                iii_strict_without_convention_share=r(strict - conv, n), undetermined_strict=n - strict,
                several_to_one_mech_chief=g("T:several:->one(chief)"),
                several_to_one_mech_dept_tier1=g("T:several:->one(dept-tier1)"),
                several_to_one_mech_dept_tier2=g("T:several:->one(dept-tier2)"),
                contradicted_holder_in_other_post=g("T:one:CONTRADICTED-holder-in-other-post"),
                contradicted_within_180d=g("T:one:CONTRADICTED-within-180d-of-hypothesised-post"),
                contradicted_holder_in_no_post=g("T:one:CONTRADICTED-holder-in-no-post-on-date"),
                one_chapter_several=g("T:one:chapter-several"), one_chapter_names_another=g("T:one:chapter-names-another"))


def tally(K, D, pclass, pslug):
    K["rows"] += 1
    K["pocom:" + pclass] += 1
    comb_none = "combined:" + ("pocom-one-no-hypothesis" if pclass == "one" else "undetermined")
    if D.get("no_record"):
        K["no_harness_record"] += 1
        K["T:no-hypothesis:no-harness-record"] += 1
        K[comb_none] += 1
        return
    K["grain:" + D["grain"]] += 1
    if not D["alts"]:
        K["T:" + D["trans"]] += 1
        K[comb_none] += 1
        return
    K["rows_with_hypothesis"] += 1
    if D["covered"]:
        K["rows_with_covered_hypothesis"] += 1
    for u in set(D["uncovered"]):
        K["uncovered_alternative:" + u] += 1
    n = D["n"]
    K["chapter:" + {0: "zero", 1: "one"}.get(n, "several")] += 1
    parts = D["parts"]
    if n == 1 and parts[0] and parts[1]:
        K["chapter_one_tier1_over_same_surname_tier2"] += 1
    if n == 1 and D["tier"] == "tier2":
        K["chapter_one_via_tier2"] += 1
    trans = D["trans"]
    K["T:" + trans] += 1
    if trans.startswith("one:CONTRADICTED") and D["uncovered"]:
        K["contradicted_but_side_has_uncovered_alternative"] += 1
    if trans.endswith("explained-as-uncovered-role"):
        K["explained_side_uncovered_only" if D["side_all_uncovered"] else "explained_side_mixed_covered_and_uncovered"] += 1
        for u in set(D["uncovered"]):
            K["explained_by:%s:%s" % (pclass, u)] += 1
    if n == 1:
        K["combined:chapter-one(" + ("corroborated" if pclass == "one" and next(iter(D["cand"])) == pslug else "from-" + pclass) + ")"] += 1
    elif pclass == "one":
        K["combined:pocom-one-" + trans.split(":", 1)[1]] += 1
    else:
        K["combined:undetermined"] += 1


def circular(ac):
    """Header words the compiled classifier itself read for this document (so a header proxy is not independent)."""
    if ac is None:
        return False
    if ac.get("kind_used") == "foreign-legation":
        return True
    cats = {x["category"] for x in ac["cands"]}
    return bool(cats & {"consularInstructions", "notesToForeignConsuls", "domesticLetters",
                        "specialAgentsDespatches", "specialAgentsInstructions"})


def main():
    os.makedirs(OUT, exist_ok=True)
    scope = S.scope_volumes(1905)
    keep = set(scope)
    DB = S.load_docs(S.BEFORE, keep)
    DA = S.load_docs(S.AFTER, keep)
    if set(DB) != set(DA):
        raise SystemExit("before/after document sets differ")
    surnames, spans, by_surname = MP.load_pocom()
    posts, post_stats = PP.load_posts()
    psur, pfull = PP.load_people()
    all_post_keys = list(posts.keys())

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

    op_cache = {}

    def other_post(sur, date):
        if (sur, date) not in op_cache:
            out = set()
            for k in all_post_keys:
                for s in surname_match(PP.holders(posts, k, date), sur):
                    out.add((s, k))
            op_cache[(sur, date)] = out
        return op_cache[(sur, date)]

    def decide(ac, date, grain, side, sur, pclass, pslug):
        alts = []
        if ac is not None and date is not None:
            Hh = M.hypotheses(ac["classifications"], ac["terr"], ac["legation_kind"])
            if grain == "head":
                alts = Hh[side]
            elif grain == "enclosure":
                for sd in ("from", "to"):
                    for a in Hh[sd]:
                        if a not in alts:
                            alts.append(a)
        covered = [a for a in alts if a[0] in ("dept", "chief")]
        uncovered = [a[1] for a in alts if a[0] == "unc"]
        D = {"grain": grain, "alts": bool(alts), "covered": bool(covered), "uncovered": uncovered, "cand": set(),
             "n": None, "tier": None, "parts": (set(), set(), set()), "mech": None, "side_all_uncovered": False}
        if not alts:
            why = "no-classification" if ac is None else ("no-date" if date is None else "grain-" + grain)
            D["trans"] = "no-hypothesis:" + why
            return D
        if sur:
            cand, tier, parts = chapter_rule(covered, sur, date)
        else:
            cand, tier, parts = set(), None, (set(), set(), set())
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
        if pclass == "one":
            if n == 1:
                trans = ("one:corroborated(%s)" % mech) if next(iter(cand)) == pslug else "one:chapter-names-another"
            elif n > 1:
                trans = "one:chapter-several"
            else:
                op = other_post(sur, date) if sur else set()
                hyp_keys = set()
                for a in covered:
                    if a[0] == "dept":
                        hyp_keys |= {"dept:" + p for p in PP.DEPT_TIER1 + PP.DEPT_TIER2}
                    else:
                        hyp_keys |= {"chief:" + t for t in a[1]}
                op_out = {(s, k) for s, k in op if k not in hyp_keys}
                slack_cand = chapter_rule(covered, sur, date, SLACK)[0] if sur else set()
                if not covered:
                    trans = "one:untestable-uncovered-only"
                elif op_out:
                    trans = "one:CONTRADICTED-holder-in-other-post"
                elif slack_cand:
                    trans = "one:CONTRADICTED-within-%dd-of-hypothesised-post" % SLACK
                else:
                    trans = "one:CONTRADICTED-holder-in-no-post-on-date"
                D["op_out"] = sorted(k for s, k in op_out)
        elif pclass == "several":
            trans = ("several:->one(%s)" % mech) if n == 1 else ("several:chapter-several" if n > 1 else
                                                         ("several:zero-uncovered-alternative" if uncovered else "several:zero"))
        else:
            if n == 1:
                trans = pclass + ":->one"
            elif n > 1:
                trans = pclass + ":chapter-several"
            elif uncovered:
                trans = pclass + ":explained-as-uncovered-role"
            else:
                trans = pclass + ":unexplained"
        D.update(trans=trans, cand=cand, n=n, tier=tier, parts=parts, mech=mech,
                 side_all_uncovered=bool(uncovered) and not covered)
        return D

    T = collections.defaultdict(collections.Counter)
    LB = collections.defaultdict(collections.Counter)
    LBD = collections.defaultdict(set)
    LSIG = collections.defaultdict(collections.Counter)
    LEX = collections.defaultdict(list)
    EV = collections.defaultdict(collections.Counter)
    EVX = collections.defaultdict(list)
    RECON = collections.defaultdict(collections.Counter)
    RECONX = collections.defaultdict(list)
    SEW = collections.defaultdict(collections.Counter)
    SEWX = collections.defaultdict(list)
    HUN = []
    DOCK = collections.defaultdict(collections.Counter)

    # ---- document-level reach over every scope document (live-index export population)
    for (v, d), ra in DA.items():
        rb = DB[(v, d)]
        b = S.band_of_volume(v)
        kind = S.doc_kind(ra)
        for k2 in ((b, "all"), (b, "kind:" + kind)):
            DOCK[k2]["docs"] += 1
        for arm, r_ in (("S_before", rb), ("S_after", ra), ("T_before", rb), ("T_after", ra)):
            ac = S.arm_S(r_) if arm.startswith("S") else S.arm_T(r_)
            F, Tt = S.roles_from(ac["cands"], ac["geo_ok"]) if ac else (frozenset(), frozenset())
            for k2 in ((b, "all"), (b, "kind:" + kind)):
                DOCK[k2][arm + ":any-label"] += bool(F or Tt)
                DOCK[k2][arm + ":both-sides-single"] += (len(F) == 1 and len(Tt) == 1)
                if arm.startswith("S"):
                    DOCK[k2][arm + ":shown"] += ac is not None
                    DOCK[k2][arm + ":shown-subset-of-candidates"] += bool(ac) and len(ac["classifications"]) < len(ac["cands"])
                if arm.endswith("after") and ac:
                    DOCK[k2][arm + ":sender-rule-decided"] += S.sender_rule_decided(ra, ac["chapter"])

    rows_out = gzip.open(os.path.join(OUT, "rows.jsonl.gz"), "wt", encoding="utf-8")
    for vi, vol in enumerate(scope):
        b = S.band_of_volume(vol)
        doc_years = MP.tei_doc_years(vol)
        rows = ner_store.volume_layer(S.MARKED, "marked", vol)
        texts = {}
        with gzip.open(os.path.join(TEXT, vol + ".jsonl.gz"), "rt", encoding="utf-8") as f:
            for line in f:
                x = json.loads(line)
                texts[x["d"]] = x["t"]
        ctx = {}
        for d, text in texts.items():
            ra = DA.get((vol, d))
            if ra is None:
                ctx[d] = None
                continue
            rb = DB[(vol, d)]
            hn = " ".join((ra.get("header") or "").split())
            hn0 = hn
            pos = -1
            if hn:
                pos = text.find(hn, 0, 80 + len(hn))
                if pos < 0:
                    hn2 = hn.replace("&", "&amp;")
                    pos = text.find(hn2, 0, 80 + len(hn2))
                    if pos >= 0:
                        hn = hn2
            pos0 = text.find(hn0, 0, 80 + len(hn0)) if hn0 else -1
            date, _ = M.parse_date(ra)
            ctx[d] = {"rb": rb, "ra": ra, "head": (pos, pos + len(hn)) if pos >= 0 else None, "hn": hn,
                      "head0": (pos0, pos0 + len(hn0)) if pos0 >= 0 else None, "date": date,
                      "arms": {arm: arm_ctx(arm, rb, ra) for arm in ARMS}, "kind": S.doc_kind(ra), "text": text}

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
            rec = {"v": vol, "d": x["d"], "t": x["t"], "s": x["s"], "e": x["e"], "n": x["n"], "band": b,
                   "sur": sur, "pocom": pclass, "pslug": pslug}
            if c is None:
                rec.update(grain="no-harness-record", kind="no-harness-record")
                for arm in ARMS:
                    D = {"no_record": True, "trans": "no-hypothesis:no-harness-record"}
                    for key in ((arm, b), (arm, b, "kind:no-harness-record"), (arm, b, "grain:no-harness-record")):
                        tally(T[key], D, pclass, pslug)
                    rec[arm] = D["trans"]
                for arm in LABEL_ARMS:
                    for key in ((arm, b), (arm, b, "kind:no-harness-record")):
                        LB[key]["rows"] += 1
                        LBD[key + ("docs",)].add((vol, x["d"]))
                rows_out.write(json.dumps(rec) + "\n")
                continue
            grain = "enclosure"
            if c["head"] and x["s"] >= c["head"][0] and x["e"] <= c["head"][1]:
                grain = "head"
            elif c["head"] is None and c["hn"]:
                grain = "head-unlocated"
            elif not c["hn"]:
                grain = "no-header"
            kind = c["kind"]
            rec.update(grain=grain, kind=kind)
            Ds = {}
            for arm in ARMS:
                ac = c["arms"][arm]
                D = decide(ac, c["date"], grain, x["t"], sur, pclass, pslug)
                Ds[arm] = D
                used = str((ac or {}).get("kind_used")) if arm in LABEL_ARMS else "n/a"
                for key in ((arm, b), (arm, b, "kind:" + kind), (arm, b, "grain:" + grain),
                            (arm, b, "kind:" + kind, "used:" + used)):
                    tally(T[key], D, pclass, pslug)
                rec[arm] = D["trans"]
                rec[arm + ":used"] = used
                if D["cand"]:
                    rec[arm + ":cand"] = sorted(D["cand"])

            # ---- the filing-role label, and the header-office proxy at row level
            ev = None
            if grain == "head":
                snd, adr = S.header_sides(c["ra"].get("header"))
                seg = snd if x["t"] == "from" else adr
                ev = S.segment_evidence(seg) if seg is not None else None
                if ev:
                    rec["header_evidence"] = [sorted(map(str, ev[0])), ev[1], ev[2]]
            for arm in LABEL_ARMS:
                ac = c["arms"][arm]
                own = other = frozenset()
                if ac is not None:
                    F, Tt = S.roles_from(ac["cands"], ac["geo_ok"])
                    own, other = (F, Tt) if x["t"] == "from" else (Tt, F)
                labeled = grain == "head" and bool(own)
                for key in ((arm, b), (arm, b, "kind:" + kind)):
                    L = LB[key]
                    L["rows"] += 1
                    L["head_rows"] += grain == "head"
                    L["labeled_rows"] += labeled
                    L["labeled_single"] += labeled and len(own) == 1
                    L["labeled_multi"] += labeled and len(own) > 1
                    LBD[key + ("docs",)].add((vol, x["d"]))
                    if grain == "head":
                        LBD[key + ("docs_head",)].add((vol, x["d"]))
                    if labeled:
                        LBD[key + ("docs_labeled",)].add((vol, x["d"]))
                if labeled:
                    sig = x["t"] + ":" + "|".join(sorted(k for k, _ in own))
                    LSIG[(arm, b)][sig] += 1
                    rec[arm + ":label"] = S.render_row_label(own, other, x["t"])
                    if arm == "S_after" and len(LEX[(b, sig)]) < 4:
                        LEX[(b, sig)].append({"doc": vol + "/" + x["d"], "name": x["n"], "header": c["hn"][:100],
                                              "dateline": (c["ra"].get("dateline") or "")[:80], "chapter": ac.get("chapter"),
                                              "label": rec[arm + ":label"]})
                if ev is not None:
                    roles_ev, strength, tag = ev
                    circ = "circular" if circular(ac) else "independent"
                    out_ = S.judge(own, roles_ev) if labeled else "unlabeled"
                    EV[(arm, b, strength, circ)][out_] += 1
                    EV[(arm, b, strength, circ, "tag:" + tag)][out_] += 1
                    if labeled and out_ in ("wrong-kind", "wrong-place") and len(EVX[(arm, b, circ, out_)]) < 15:
                        EVX[(arm, b, circ, out_)].append({"doc": vol + "/" + x["d"], "side": x["t"], "name": x["n"],
                                                          "header": c["hn"][:110], "dateline": (c["ra"].get("dateline") or "")[:70],
                                                          "chapter": ac.get("chapter"), "label": S.render_row_label(own, other, x["t"]),
                                                          "evidence": sorted(map(str, roles_ev)), "tag": tag})

            # ---- reconciliation (1861-1899)
            if b == "1861-1899":
                sc = {a: short(Ds[a]["trans"]) for a in ARMS}
                RECON["B0 x T_after"][(sc["B0"], sc["T_after"])] += 1
                RECON["B0 x B_after"][(sc["B0"], sc["B_after"])] += 1
                RECON["B_after x T_after"][(sc["B_after"], sc["T_after"])] += 1
                RECON["S_before x S_after"][(sc["S_before"], sc["S_after"])] += 1
                RECON["T_before x T_after"][(sc["T_before"], sc["T_after"])] += 1
                if sc["B0"] != sc["T_after"]:
                    a0, at = c["arms"]["B0"], c["arms"]["T_after"]
                    cats0 = tuple(sorted({k["category"] for k in a0["classifications"]})) if a0 else None
                    catst = tuple(sorted({k["category"] for k in at["classifications"]})) if at else None
                    fact = ("B0.via=%s" % (a0.get("via") if a0 else None), "B0.legkind=%s" % (a0.get("legation_kind") if a0 else None),
                            "T.used=%s" % (at.get("kind_used") if at else None),
                            "terr-same=%s" % ((a0 or {}).get("terr") == (at or {}).get("terr")), "cats-same=%s" % (cats0 == catst))
                    RECON["B0!=T_after facts"][fact] += 1
                    RECON["B0!=T_after transition pairs"][(sc["B0"], sc["T_after"])] += 1
                    if len(RECONX[fact]) < 5:
                        RECONX[fact].append({"doc": vol + "/" + x["d"], "side": x["t"], "grain": grain, "name": x["n"],
                                             "header": c["hn"][:80], "dateline": (c["ra"].get("dateline") or "")[:60],
                                             "B0": [a0.get("chapter") if a0 else None, (a0 or {}).get("terr"), cats0, Ds["B0"]["trans"]],
                                             "T_after": [at.get("chapter") if at else None, (at or {}).get("terr"), catst, Ds["T_after"]["trans"]]})

            # ---- Seward 1861-1869 (seward_crosstab.py's population and signature rule)
            if sur == "Seward" and c["date"] and datetime.date(1861, 1, 1) <= c["date"] <= datetime.date(1869, 12, 31) \
                    and 1861 <= int(vol[4:8]) <= 1869:
                text = c["text"]
                grain0 = "head" if (c["head0"] and x["s"] >= c["head0"][0] and x["e"] <= c["head0"][1]) else "enclosure"
                m = SIG.search(text)
                first = "none" if not m else ("F.W." if "F" in m.group(1)[:9] else "W.H.")
                init = "F.W." if re.search(r"\bF\.\s*W\.|Frederick", x["n"]) else ("W.H." if re.search(r"\bW(?:m|illiam)?\.?\s*H\.|William", x["n"]) else "bare")
                classes = ["all Seward rows 1861-69"]
                if grain0 == "head" and x["t"] == "from":
                    classes.append("head-from (earlier 3,669)")
                    if first == "F.W.":
                        classes.append("head-from, first signature F.W. (earlier 117)")
                if grain0 == "head" and x["t"] == "from" and init == "F.W.":
                    classes.append("head-from naming F.W. (earlier 113)")
                    if first == "F.W.":
                        classes.append("head-from naming F.W., first signature F.W. (earlier 108)")
                if grain0 == "head" and init == "F.W.":
                    classes.append("head naming F.W., either side")
                if grain0 == "head" and x["t"] == "from" and first == "F.W." and init != "F.W.":
                    classes.append("head-from bare name, first signature F.W. (earlier 9)")
                for cl in classes:
                    Z = SEW[cl]
                    Z["rows"] += 1
                    Z["kind:" + kind] += 1
                    Z["header sender matches the merged secretaryOfStateSender pattern"] += S.sos_sender(c["ra"].get("header"))
                    for arm in ("B0", "S_before", "S_after", "T_before", "T_after"):
                        ac = c["arms"][arm]
                        D = Ds[arm]
                        cats = "+".join(sorted({k["category"] for k in ac["classifications"]})) if ac else "none"
                        Z[arm + ":cats=" + cats] += 1
                        who = "W.H." if D["cand"] == {WH} else ("F.W." if D["cand"] == {FW} else ("none" if not D["cand"] else "other"))
                        Z[arm + ":chapter-rule=" + who] += 1
                        if arm.startswith("S"):
                            Z[arm + ":shown"] += ac is not None
                        if arm.endswith("after") and ac:
                            Z[arm + ":sender-rule-decided"] += S.sender_rule_decided(c["ra"], ac["chapter"])
                    if cl != "all Seward rows 1861-69" and len(SEWX[cl]) < 12:
                        sa, ta = c["arms"]["S_after"], c["arms"]["T_after"]
                        SEWX[cl].append({"doc": vol + "/" + x["d"], "date": str(c["date"]), "side": x["t"], "name": x["n"],
                                         "header": c["hn"][:80], "dateline": (c["ra"].get("dateline") or "")[:60], "kind": kind,
                                         "S_after": sorted({k["category"] for k in sa["classifications"]}) if sa else None,
                                         "T_after": sorted({k["category"] for k in ta["classifications"]}) if ta else None,
                                         "sender_rule_decided": S.sender_rule_decided(c["ra"], (sa or ta or {}).get("chapter")),
                                         "chapter_rule_T_after": sorted(Ds["T_after"]["cand"]), "signature": first})

            # ---- Hunter in POCOM's gap (chief clerk ends 1855-05-07; second assistant starts 1866-07-27)
            if sur == "Hunter" and c["date"] and HUNTER_LO <= c["date"] <= HUNTER_HI:
                item = {"doc": vol + "/" + x["d"], "date": str(c["date"]), "side": x["t"], "grain": grain, "name": x["n"],
                        "header": c["hn"][:90], "dateline": (c["ra"].get("dateline") or "")[:70], "kind": kind, "pocom": pclass,
                        "pocom_slug": pslug}
                for arm in ("B0", "S_before", "S_after", "T_before", "T_after"):
                    ac = c["arms"][arm]
                    item[arm] = {"chapter": ac.get("chapter") if ac else None,
                                 "cats": sorted({k["category"] for k in ac["classifications"]}) if ac else None,
                                 "trans": Ds[arm]["trans"], "cand": sorted(Ds[arm]["cand"])}
                    if arm.endswith("after"):
                        item[arm]["sender_rule_decided"] = S.sender_rule_decided(c["ra"], ac["chapter"]) if ac else False
                HUN.append(item)
            rows_out.write(json.dumps(rec) + "\n")
        print(f"[{vi + 1}/{len(scope)}] {vol}", file=sys.stderr)
    rows_out.close()

    # ------------------------------------------------------------------ outputs
    summaries = {"|".join(k): summarize(v) for k, v in T.items()}
    earlier = {f'{r["arm"]}|{r["band"]}': r for r in json.load(open(EARLIER_SUMMARY))}
    controls = {}
    for mine, theirs in (("A0", "A"), ("B0", "B")):
        for band in ("1861-1899", "1900-1905"):
            e = earlier[f"{theirs}|{band}"]
            s = summaries[f"{mine}|{band}"]
            diffs = {k: (s.get(k), e[k]) for k in e if k not in ("arm", "band") and s.get(k) != e[k]}
            controls[f"{mine} vs earlier {theirs} {band}"] = "PASS (all %d fields equal)" % (len(e) - 2) if not diffs else {"FAIL": diffs}
    labels = {}
    for key, L in LB.items():
        d = dict(L)
        for sfx in ("docs", "docs_head", "docs_labeled"):
            d[sfx] = len(LBD.get(key + (sfx,), ()))
        labels["|".join(key)] = d
    proxy = {"|".join(k): S.precision_block(v) | {"counts": dict(v)} for k, v in EV.items()}
    out = {
        "generated_by": os.path.abspath(__file__),
        "inputs": {"before": S.BEFORE, "after": S.AFTER, "marked": S.MARKED, "text": TEXT, "scope_volumes": scope,
                   "pocom_post_load_stats": dict(post_stats)},
        "controls_against_earlier_summary": controls,
        "summaries": summaries,
        "document_reach_all_scope_documents": {"|".join(k): dict(v) for k, v in DOCK.items()},
        "labels_row_reach": labels,
        "label_signatures": {"|".join(k): dict(v.most_common()) for k, v in LSIG.items()},
        "label_examples_S_after": {"|".join(k): v for k, v in LEX.items()},
        "header_office_proxy_rows": proxy,
        "header_office_proxy_wrong_examples": {"|".join(k): v for k, v in EVX.items()},
        "reconciliation": {k: sorted(([list(kk), vv] for kk, vv in v.items()), key=lambda z: -z[1]) for k, v in RECON.items()},
        "reconciliation_examples": {" ".join(k): v for k, v in RECONX.items()},
        "seward_1861_1869": {k: dict(sorted(v.items())) for k, v in SEW.items()},
        "seward_examples": SEWX,
        "hunter_gap_rows": HUN,
    }
    json.dump(out, open(os.path.join(OUT, "merged-rule.json"), "w"), indent=1, sort_keys=True, default=list)
    print(json.dumps(controls, indent=1))
    print("wrote", os.path.join(OUT, "merged-rule.json"), file=sys.stderr)


if __name__ == "__main__":
    main()
