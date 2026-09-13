#!/usr/bin/env python3
"""VERIFIER script 5: a deliberately simple, independent re-derivation of the 1900-1905 printed-office proxy.
Population: every export document in the 9 no-list volumes dated by volume id 1900-1905 (after-docs.jsonl). Header split at
the first ' to ' (memoranda skipped). Evidence classes from the printed side, verifier's own patterns, checked in order:
foreign-office, department, us-mission (office 'of the United States' / 'American' / 'Ambassador|Minister|Charge in|at X'),
foreign-legation (adjective + minister/legation/charge/ambassador), us-consulate, us-domestic-office (President, cabinet),
weak 'Minister X'. Label = verifier V1 roles for that side. Judged by KIND only. Writes out/header-proxy.json."""
import os, re, json, collections, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v_shown_labels import AFTER, roles, band

HERE = os.path.dirname(os.path.abspath(__file__))
ADJ = r"(?:british|french|spanish|german|mexican|chinese|italian|russian|japanese|belgian|netherlands|dutch|swiss|danish|swedish|norwegian|austro-hungarian|austrian|portuguese|brazilian|chilean|peruvian|argentine|colombian|venezuelan|turkish|greek|haitian|dominican|cuban|guatemalan|salvadorean|nicaraguan|honduran|costa rican|ecuadorian|bolivian|paraguayan|uruguayan|korean|siamese|persian|hawaiian|liberian|roumanian|servian|panamanian|moroccan)"
PATS = [
    ("foreign-office", re.compile(r"minister (?:of|for) (?:foreign|exterior)|foreign office|foreign minister|secretary of state for foreign|tsungli yamen|prime minister|grand vizier|minister of state")),
    ("department", re.compile(r"secretary of state|acting secretary|department of state")),
    ("us-mission", re.compile(r"(?:ambassador|minister|charg\S*|legation|embassy)[^,;]* of the united states(?! of (?:colombia|mexico|brazil|venezuela))|american (?:ambassador|minister|charg|legation|embassy)|^(?:the )?(?:ambassador|minister|charg\S*(?: d.affaires)?(?: ad interim)?) (?:in|at|to) ")),
    ("foreign-legation", re.compile(ADJ + r" (?:minister|legation|charg|ambassador|embassy|envoy)")),
    ("us-consulate", re.compile(r"consul")),
    ("us-domestic-office", re.compile(r"^(?:the )?president(?: of the united states)?\b|secretary of (?:war|the navy|the treasury|the interior|agriculture|commerce)|attorney.general|postmaster")),
    ("weak-minister", re.compile(r"^(?:ambassador|minister|charg\S*) (?!of |for |in |at |to )[a-z]")),
]

def ev(seg):
    s = " ".join(seg.lower().split())
    s = re.sub(r"^no\. ?\d+\.?\s*", "", s).strip(" .,")
    for k, p in PATS:
        if p.search(s):
            return k
    return None

def main():
    C = collections.defaultdict(collections.Counter); X = collections.defaultdict(list)
    for l in open(AFTER):
        r = json.loads(l)
        if band(r["volume"]) != "1900-1905":
            continue
        scope = json.load(open(os.path.expanduser("~/frus-ner-raw/scope.json")))["volumes"] if not hasattr(main, "sc") else main.sc
        main.sc = scope
        if r["volume"] not in scope:
            continue
        C["docs"]["n"] += 1
        h = " ".join((r.get("header") or "").split())
        if re.match(r"^(?:no\. ?\d+\.?\s*)?(?:memorandum|aide-m|note verbale|pro memoria)", h.lower()) or " to " not in h.lower():
            continue
        i = h.lower().find(" to ")
        sides = {"from": h[:i], "to": h[i + 4:]}
        F, T = roles(r, "V1")
        anyev = False
        for side, seg in sides.items():
            e = ev(seg)
            if not e:
                continue
            anyev = True
            own = {k for k, _ in (F if side == "from" else T)}
            if not own:
                C["sides"]["evidence, unlabelled"] += 1
                continue
            lab = "|".join(sorted(own))
            if e == "weak-minister":
                C["weak"][lab + (":kind-consistent" if "us-mission" in own or "foreign-legation" in own else ":inconsistent")] += 1
                continue
            ok = e in own
            if e == "foreign-office" and "foreign-legation" in own:
                ok = False
            C["by-label"][lab + (":right-kind" if ok else ":wrong-kind")] += 1
            C["sides"]["judged"] += 1
            C["sides"]["right-kind"] += ok
            if not ok and len(X[lab]) < 8:
                X[lab].append([r["volume"] + "/" + r["d"], side, h[:110], (r.get("dateline") or "")[:50], r.get("chosenTitle"), e])
        C["docs"]["with strict-or-weak evidence on a side"] += anyev
    R = {k: dict(v) for k, v in C.items()}
    R["wrong_examples"] = X
    json.dump(R, open(os.path.join(HERE, "out", "header-proxy.json"), "w"), indent=1, sort_keys=True)
    print(json.dumps(R, indent=1, sort_keys=True))

if __name__ == "__main__":
    main()
