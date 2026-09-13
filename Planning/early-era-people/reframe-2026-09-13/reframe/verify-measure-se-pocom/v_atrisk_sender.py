#!/usr/bin/env python3
"""VERIFIER script 6: (i) shown 1861-1899 scope documents resting on the MEDIUM-confidence despatch fallback, split by
header addressee (verifier's own coarse rule: Secretary/Department surname or office after ' to '); (ii) documents where
the merged sender rule decided direction (shown, chosen title a foreign-legation title by the verifier's detector,
dateline without 'department of state' and without a U.S.-legation phrase, header sender matching the Swift regex copied
from CentralFilesClassifier.secretaryOfStateSender, and a notes-to/instructions resolution shown). Writes out/atrisk-sender.json."""
import os, re, json, collections, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v_shown_labels import AFTER, band, legation_title, SOS, US_LEG_DL

HERE = os.path.dirname(os.path.abspath(__file__))
SEC = re.compile(r"secretary of state|department of state|acting secretary|\bmr\.? (?:[a-z]\. ?)*(?:seward|fish|evarts|blaine|frelinghuysen|bayard|foster|gresham|olney|sherman|day|hay|hunter|adee|wharton|uhl|washburne|davis|cadwalader|porter|rives|hale|payson|brown)\b")

def main():
    scope = set(json.load(open(os.path.expanduser("~/frus-ner-raw/scope.json")))["volumes"])
    C = collections.defaultdict(collections.Counter); X = collections.defaultdict(list)
    for l in open(AFTER):
        r = json.loads(l)
        b = band(r["volume"])
        if not b or r["volume"] not in scope or not r["shown"]:
            continue
        Z = C[b]
        Z["shown docs"] += 1
        cats = {(c["category"], c.get("confidence")) for c in r["shown"]}
        hl = " ".join((r.get("header") or "").lower().split())
        dl = (r.get("dateline") or "").lower()
        if ("diplomaticDespatches", "medium") in cats:
            Z["medium despatch fallback"] += 1
            i = hl.find(" to ")
            if i < 0:
                Z["medium: no ' to ' in header"] += 1
            else:
                adr = hl[i + 4:]
                k = "addressee Secretary/Department" if SEC.search(adr) else "addressee other"
                Z["medium: " + k] += 1
                if k == "addressee other" and len(X[b]) < 8:
                    X[b].append([r["volume"] + "/" + r["d"], r.get("header"), r.get("dateline"), r.get("chosenTitle")])
        if ("diplomaticDespatches", "high") in cats:
            Z["high despatch"] += 1
        if legation_title(r.get("chosenTitle")) and "department of state" not in dl and not any(s in dl for s in US_LEG_DL):
            i = hl.find(" to ")
            if i >= 0 and SOS.search(hl[:i]) and any(c in ("notesToForeignMissions", "diplomaticInstructions") for c, _ in cats):
                Z["sender rule decided (verifier)"] += 1
    R = {k: dict(v) for k, v in C.items()}
    R["examples_medium_addressee_other"] = X
    json.dump(R, open(os.path.join(HERE, "out", "atrisk-sender.json"), "w"), indent=1, sort_keys=True)
    print(json.dumps(R, indent=1, sort_keys=True))

if __name__ == "__main__":
    main()
