#!/usr/bin/env python3
"""VERIFIER script 2 (independent of measure-se-pocom code). Reads the compiled classifier's per-document output
(geo-fix/before-docs.jsonl, geo-fix/after-docs.jsonl) directly, the verifier's own TEI-grain rows
(out/rows-verify.jsonl.gz from v_population.py), the R-0 text layer (Seward signatures) and POCOM XML (Hunter).
Nothing imported from measure-se-pocom. Writes out/shown-labels.json.

Label definitions (re-typed from the claim, not copied):
  V1 "chosen-title candidates": categories = classifierByTitle[chosenTitleIndex].classifications when the document is
     shown, else none; a diplomatic category needs its own geoKeys AND (a shown diplomatic geoKey OR the chosen title is
     served by a diplomatic roll). (The claim's country test also admits titles in its GEO crosswalk; that part is not
     re-implemented, so V1 can only be <= the claim's figure on that axis.)
  V2 "shown only": categories = shown resolutions; a diplomatic category needs its own geoKeys.
A row is LABELLED when it is a TEI head row (the document's own <head>) and its own side has at least one role.
"""
import os, re, json, gzip, collections, datetime, glob
import xml.etree.ElementTree as ET

SP = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad"
BEFORE, AFTER = SP + "/geo-fix/before-docs.jsonl", SP + "/geo-fix/after-docs.jsonl"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
TEXT = os.path.expanduser("~/frus-semantic-raw/text")
DIPLO = {"diplomaticDespatches", "diplomaticInstructions", "notesToForeignMissions", "notesFromForeignMissions"}
ROLES = {  # category -> (from-role, to-role)
    "diplomaticDespatches": ("us-mission", "department"), "diplomaticInstructions": ("department", "us-mission"),
    "notesToForeignMissions": ("department", "foreign-legation"), "notesFromForeignMissions": ("foreign-legation", "department"),
    "consularDespatches": ("us-consulate", "department"), "notesFromForeignConsuls": ("foreign-consul", "department"),
    "notesToForeignConsuls": ("department", "foreign-consul"), "consularInstructions": ("department", "us-consulate"),
    "lettersReceived": ("us-domestic-office", "department"), "domesticLetters": ("department", "us-domestic-office"),
    "specialAgentsDespatches": ("special-agent", "department"), "specialAgentsInstructions": ("department", "special-agent")}
SOS = re.compile(r"\b(?:secretary of state(?! for)|mr\.? (?:[a-z]\. ?)*(?:seward|fish|evarts|blaine|frelinghuysen|bayard|foster|gresham|olney|sherman|day|hay|root|hunter|adee|wharton|uhl))\b")
US_LEG_DL = ["legation of the united states", "embassy of the united states", "american legation", "american embassy",
             "united states legation", "u. s. legation", "u.s. legation"]
SIG = re.compile(r"(F\.\s*W\.\s*SEWARD|FREDERICK W\.\s*SEWARD|WILLIAM H\.\s*SEWARD|W\.\s*H\.\s*SEWARD)")


def band(v):
    y = int(v[4:8])
    return "1861-1899" if y <= 1899 else ("1900-1905" if y <= 1905 else None)


def legation_title(title):
    """VERIFIER's own detector: a chapter of correspondence with a FOREIGN legation/embassy (in Washington)."""
    t = " ".join((title or "").lower().split())
    t = re.sub(r"^\[\d+\]\s*", "", t)
    t = re.sub(r"^\*?\s*(?:[ivxlcdm]+|\d{1,3})\.\s*[—–-]\s*", "", t)
    t = re.sub(r"\(\s*continued\.?\s*\)", "", t).strip(" .")
    if not re.search(r"\b(?:legation|embassy)\b", t):
        return False
    if re.search(r"(?:legation|embassy) of the united states(?! of colombia)|united states (?:legation|embassy)|american (?:legation|embassy)|u\. ?s\. (?:legation|embassy)", t):
        return False
    if re.search(r"\b(?:at|in) (?!washington)[a-z]", t.split("legation")[-1].split("embassy")[-1]):
        return False
    return True


def date_of(r):
    for k in ("datelineDateISO", "dateIsoIndex"):
        x = r.get(k)
        if x and re.match(r"^\d{4}-\d{2}-\d{2}$", x):
            try:
                return datetime.date(*map(int, x.split("-")))
            except ValueError:
                pass
    return None


def roles(r, variant):
    shown = r.get("shown") or []
    if not shown:
        return set(), set()
    shown_geo = any(c["category"] in DIPLO and c.get("geoKeys") for c in shown)
    if variant == "V1":
        ci = r.get("chosenTitleIndex")
        cbt = r.get("classifierByTitle") or []
        t = cbt[ci] if ci is not None and ci < len(cbt) else None
        cands = t["classifications"] if t else shown
        geo_ok = shown_geo or bool(t and t.get("titleKeyServedByDiplomaticRoll"))
    else:
        cands, geo_ok = shown, True
    F, T = set(), set()
    for c in cands:
        cat = c["category"]
        if cat not in ROLES:
            continue
        g = (c.get("geoKeys") or [None])[0]
        if cat in DIPLO and not (geo_ok and g):
            continue
        f, to = ROLES[cat]
        F.add((f, g if f in ("us-mission", "foreign-legation", "us-consulate") else None))
        T.add((to, g if to in ("us-mission", "foreign-legation", "us-consulate") else None))
    return F, T


def main():
    rows = [json.loads(l) for l in gzip.open(os.path.join(OUT, "rows-verify.jsonl.gz"), "rt")]
    vols = {r["v"] for r in rows}
    # all scope volumes (incl. any with no rows) from scope.json
    scope = [v for v in json.load(open(os.path.expanduser("~/frus-ner-raw/scope.json")))["volumes"] if band(v)]
    DA, DB = {}, {}
    for path, D in ((AFTER, DA), (BEFORE, DB)):
        for l in open(path):
            r = json.loads(l)
            if r["volume"] in scope:
                D[(r["volume"], r["d"])] = r
    R = {}
    # ---- document reach (live-index export population)
    DR = collections.defaultdict(collections.Counter)
    for k, ra in DA.items():
        rb = DB[k]
        b = band(k[0])
        Z = DR[b]
        Z["docs"] += 1
        Z["after:shown"] += bool(ra["shown"])
        Z["before:shown"] += bool(rb["shown"])
        for var in ("V1", "V2"):
            F, T = roles(ra, var)
            Z[var + ":after:any-label"] += bool(F or T)
            Fb, Tb = roles(rb, var)
            Z[var + ":before:any-label"] += bool(Fb or Tb)
        # label uses a category that is NOT shown (V1 vs shown)
        if ra["shown"]:
            ci = ra.get("chosenTitleIndex")
            cbt = ra.get("classifierByTitle") or []
            if ci is not None and ci < len(cbt):
                cc = {c["category"] for c in cbt[ci]["classifications"]}
                sc = {c["category"] for c in ra["shown"]}
                Z["after:chosen-title-candidate-categories-not-shown"] += bool(cc - sc)
            else:
                Z["after:shown-but-no-chosen-title-index"] += 1
        # legation-kind documents and the title the shown walk used
        if b == "1861-1899" or b == "1900-1905":
            titles = ra.get("sectionPath") or []
            if any(legation_title(t) for t in titles):
                Z["legation-kind docs"] += 1
                if not ra["shown"]:
                    Z["legation-kind: after no shown"] += 1
                elif legation_title(ra.get("chosenTitle")):
                    Z["legation-kind: after chosen = legation title"] += 1
                else:
                    ci = ra.get("chosenTitleIndex")
                    t = (ra.get("classifierByTitle") or [])[ci] if ci is not None else None
                    Z["legation-kind: after chosen = other title (roll-served %s)" % bool(t and t.get("titleKeyServedByDiplomaticRoll"))] += 1
    R["document_reach"] = {b: dict(v) for b, v in DR.items()}

    # ---- row label reach (TEI-rule marked rows, verifier's TEI head grain)
    RR = collections.defaultdict(collections.Counter)
    DD = collections.defaultdict(set)
    texts = {}
    SEW = collections.Counter(); SEWX = []
    HUN = collections.Counter(); HUNX = []
    for x in rows:
        b = x["band"]
        k = (x["v"], x["d"])
        ra, rb = DA.get(k), DB.get(k)
        Z = RR[b]
        Z["rows"] += 1
        DD[(b, "docs")].add(k)
        if ra is None:
            Z["no export record"] += 1
            continue
        head = x["grain"] == "head"
        Z["head rows"] += head
        for arm, r_ in (("after", ra), ("before", rb)):
            for var in ("V1", "V2"):
                F, T = roles(r_, var)
                own = F if x["t"] == "from" else T
                lab = head and bool(own)
                Z["%s:%s:labelled" % (var, arm)] += lab
                Z["%s:%s:labelled-single" % (var, arm)] += lab and len(own) == 1
                if lab:
                    DD[(b, var, arm)].add(k)
        # ---- Seward 1861-69, head-from, first signature F.W.
        d = date_of(ra)
        if x["sur"] == "Seward" and d and datetime.date(1861, 1, 1) <= d <= datetime.date(1869, 12, 31) and 1861 <= int(x["v"][4:8]) <= 1869:
            SEW["rows"] += 1
            if head and x["t"] == "from":
                SEW["head-from"] += 1
                if x["v"] not in texts:
                    texts = {x["v"]: {json.loads(l)["d"]: json.loads(l)["t"] for l in gzip.open(os.path.join(TEXT, x["v"] + ".jsonl.gz"), "rt")}}
                txt = texts[x["v"]].get(x["d"], "")
                m = SIG.search(txt)
                first = None if not m else ("F.W." if m.group(1).startswith("F") else "W.H.")
                if first == "F.W.":
                    hl = (ra.get("header") or "").lower()
                    i = hl.find(" to ")
                    sender_match = i >= 0 and SOS.search(hl[:i]) is not None
                    dl = (ra.get("dateline") or "").lower()
                    leg_b = legation_title(rb.get("chosenTitle")) if rb["shown"] else False
                    leg_a = legation_title(ra.get("chosenTitle")) if ra["shown"] else False
                    any_leg = any(legation_title(t) for t in ra.get("sectionPath") or [])
                    decided = leg_a and "department of state" not in dl and sender_match and not any(s in dl for s in US_LEG_DL)
                    SEW["F.W.-first-signed"] += 1
                    SEW["F.W.: shown before"] += bool(rb["shown"])
                    SEW["F.W.: shown after"] += bool(ra["shown"])
                    SEW["F.W.: header sender matches Swift secretaryOfStateSender regex"] += sender_match
                    SEW["F.W.: dateline contains 'department of state'"] += "department of state" in dl
                    SEW["F.W.: in a legation-titled section path"] += any_leg
                    SEW["F.W.: chosen title is legation title (after)"] += leg_a
                    SEW["F.W.: sender rule decided (after)"] += decided
                    SEW["F.W.: name carries F. W. initials"] += bool(re.search(r"\bF\.\s*W\.|Frederick", x["n"]))
                    F, T = roles(ra, "V1")
                    SEW["F.W.: own label (V1 after) = " + "|".join(sorted(k_ for k_, _ in F))] += 1
                    if len(SEWX) < 6:
                        SEWX.append([x["v"] + "/" + x["d"], x["n"], ra.get("header"), ra.get("dateline"), ra.get("chosenTitle")])
        # ---- Hunter, 1865-01-01 .. 1866-07-26
        if x["sur"] == "Hunter" and d and datetime.date(1865, 1, 1) <= d <= datetime.date(1866, 7, 26):
            HUN["rows"] += 1
            g = ("head-" + x["t"]) if head else "non-head"
            HUN["grain:" + g] += 1
            HUN["pocom:" + x["pocom"] + ":" + str(x["pslug"])] += 1
            HUN["shown before"] += bool(rb["shown"])
            HUN["shown after"] += bool(ra["shown"])
            HUN["shown after, pocom one"] += bool(ra["shown"]) and x["pocom"] == "one"
            HUN["dateline has department of state (head-from)"] += head and x["t"] == "from" and "department of state" in (ra.get("dateline") or "").lower()
            if head:
                F, T = roles(ra, "V1")
                own = F if x["t"] == "from" else T
                HUN["label V1 after %s own=%s" % (g, "|".join(sorted(k_ for k_, _ in own)) or "none")] += 1
    for b in RR:
        RR[b]["docs holding rows"] = len(DD[(b, "docs")])
        for var in ("V1", "V2"):
            for arm in ("after", "before"):
                RR[b]["%s:%s:docs labelled" % (var, arm)] = len(DD[(b, var, arm)])
    R["row_label_reach"] = {b: dict(v) for b, v in RR.items()}
    R["seward"] = dict(SEW); R["seward_examples"] = SEWX
    R["hunter"] = dict(HUN)
    # ---- POCOM: every William Hunter appointment (ElementTree)
    H = []
    for p in glob.glob("/Users/jbotts/Development/pocom/positions-principals/*.xml") + glob.glob("/Users/jbotts/Development/pocom/missions-*/*.xml"):
        for el in ET.parse(p).getroot().iter():
            if el.tag in ("principal", "chief") and (el.findtext("person-id") or "").strip() == "hunter-william":
                H.append([os.path.basename(p), {t: (el.find(t).findtext("date") if el.find(t) is not None else None) for t in ("appointed", "started", "arrived", "ended")}])
    R["pocom_hunter_william_appointments"] = H
    json.dump(R, open(os.path.join(OUT, "shown-labels.json"), "w"), indent=1, sort_keys=True)
    print(json.dumps(R, indent=1, sort_keys=True))


if __name__ == "__main__":
    main()
