#!/usr/bin/env python3
"""VERIFIER script 4: the Department half of the S_after corroborated/contradicted table, re-derived independently,
then compared row by row with the claim's per-row output (measure-se-pocom/out/rows.jsonl.gz field S_after).
Population: verifier TEI head rows, 1861-1899, POCOM surname rule 'one', Source Explorer shows a resolution (after-docs),
and the row's side is hypothesised ONLY as the Department (from-side of instructions/notes-to/consular instructions/
domestic letters/special-agent instructions; to-side of high-confidence despatches, notes-from, consular despatches,
letters received, notes from foreign consuls, special-agent despatches) -- no U.S.-mission alternative on that side.
Department posts (POCOM positions-principals, ElementTree): tier 1 secretary, secretary-ad-interim; tier 2 assistant,
second assistant, third assistant secretary, chief clerk. corroborated = the POCOM pick holds a tier-1 post on the date,
or a tier-2 post with no same-surname tier-1 holder; contradicted = the pick holds no Department post on the date and no
same-surname person does. Also: rows under a chosen foreign-legation title. Writes out/dept-corroboration.json."""
import os, re, json, gzip, glob, collections, datetime, sys
import xml.etree.ElementTree as ET
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v_shown_labels import SP, AFTER, legation_title, date_of

HERE = os.path.dirname(os.path.abspath(__file__))
POCOM = "/Users/jbotts/Development/pocom"
T1 = ["secretary", "secretary-ad-interim"]
T2 = ["assistant-secretary", "second-assistant-secretary", "third-assistant-secretary", "chief-clerk"]
DEPT_FROM = {"diplomaticInstructions", "notesToForeignMissions", "consularInstructions", "notesToForeignConsuls", "domesticLetters", "specialAgentsInstructions"}
DEPT_TO = {"notesFromForeignMissions", "consularDespatches", "lettersReceived", "notesFromForeignConsuls", "specialAgentsDespatches"}

def pd(s, end):
    m = re.match(r"^\s*(\d{4})(?:-(\d{2}))?(?:-(\d{2}))?\s*$", s or "")
    if not m:
        return None
    y, mo, d = int(m.group(1)), m.group(2), m.group(3)
    if d:
        return datetime.date(y, int(mo), int(d))
    if mo:
        mo = int(mo)
        if not end:
            return datetime.date(y, mo, 1)
        nxt = datetime.date(y + (mo == 12), 1 if mo == 12 else mo + 1, 1)
        return nxt - datetime.timedelta(days=1)
    return datetime.date(y, 12, 31) if end else datetime.date(y, 1, 1)

def posts():
    P = collections.defaultdict(list)
    for tier, names in ((1, T1), (2, T2)):
        for n in names:
            for el in ET.parse(f"{POCOM}/positions-principals/{n}.xml").getroot().iter("principal"):
                pid = el.findtext("person-id").strip()
                def g(tag, end=False):
                    x = el.find(tag)
                    return pd(x.findtext("date"), end) if x is not None else None
                starts = [x for x in (g("appointed"), g("started")) if x]
                if not starts:
                    continue
                s, e = min(starts), g("ended", True)
                if e is None:
                    e = datetime.date(9999, 12, 31)
                elif e < s:
                    e = max(starts + [e])
                P[tier].append((pid, s, e))
    return P

def main():
    sur = {}
    for p in glob.glob(POCOM + "/people/*/*.xml"):
        r = ET.parse(p).getroot()
        sur[(r.findtext("id") or "").strip()] = (r.findtext(".//surname") or "").strip()
    P = posts()
    def holders(tier, d):
        return {pid for pid, s, e in P[tier] if s <= d <= e}
    DA = {}
    for l in open(AFTER):
        r = json.loads(l)
        DA[(r["volume"], r["d"])] = r
    theirs = {}
    for l in gzip.open(SP + "/reframe/measure-se-pocom/out/rows.jsonl.gz", "rt"):
        r = json.loads(l)
        theirs[(r["v"], r["d"], r["t"], r["s"])] = r
    C = collections.Counter(); X = collections.defaultdict(list); L = collections.Counter()
    for l in gzip.open(os.path.join(HERE, "out", "rows-verify.jsonl.gz"), "rt"):
        x = json.loads(l)
        if x["band"] != "1861-1899":
            continue
        ra = DA.get((x["v"], x["d"]))
        if ra is None:
            continue
        # legation-rules population: chosen shown title is a foreign-legation title (verifier detector), all grains
        if ra["shown"] and legation_title(ra.get("chosenTitle")):
            L["rows"] += 1
            L["pocom:" + x["pocom"]] += 1
            L["head rows"] += x["grain"] == "head"
        if x["grain"] != "head" or x["pocom"] != "one" or not ra["shown"]:
            continue
        d = date_of(ra)
        if d is None:
            continue
        cats = {(c["category"], c.get("confidence")) for c in ra["shown"]}
        names = {c for c, _ in cats}
        if x["t"] == "from":
            dept = bool(names & DEPT_FROM)
            mission = "diplomaticDespatches" in names
        else:
            dept = bool(names & DEPT_TO) or ("diplomaticDespatches" in names)
            mission = "diplomaticInstructions" in names or ("diplomaticDespatches", "medium") in cats
        if not dept or mission:
            continue
        C["population"] += 1
        pick = x["pslug"]; s_ = sur.get(pick)
        h1, h2 = holders(1, d), holders(2, d)
        m1 = {p for p in h1 if sur.get(p) == s_}; m2 = {p for p in h2 if sur.get(p) == s_}
        cand = m1 if m1 else m2
        if cand == {pick}:
            mine = "corroborated"
        elif cand:
            mine = "names-another-or-several"
        else:
            mine = "contradicted"
        th = theirs.get((x["v"], x["d"], x["t"], x["s"]), {}).get("S_after", "missing")
        tc = "corroborated" if th.startswith("one:corroborated") else ("contradicted" if th.startswith("one:CONTRADICTED") else ("names-another-or-several" if th in ("one:chapter-names-another", "one:chapter-several") else th))
        C["mine:" + mine] += 1
        C["theirs:" + tc] += 1
        C["cross:%s|%s" % (mine, tc)] += 1
        if mine != tc and len(X[mine + "|" + tc]) < 6:
            X[mine + "|" + tc].append([x["v"] + "/" + x["d"], x["t"], x["n"], pick, str(d), sorted(names), ra.get("header"), th])
    R = {"dept_side": dict(C), "disagreements": X, "legation_chosen_title_rows": dict(L)}
    json.dump(R, open(os.path.join(HERE, "out", "dept-corroboration.json"), "w"), indent=1, sort_keys=True)
    print(json.dumps(R, indent=1, sort_keys=True))

if __name__ == "__main__":
    main()
