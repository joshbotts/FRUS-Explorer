#!/usr/bin/env python3
"""VERIFIER script 3: the 1873 list-volume proxy, re-extracted from the TEI (no gold-*.jsonl, no lib_se).
Evidence = the persons-list entry (section xml:id="correspondents") each head from/to persName points to via @corresp:
its printed role text and the centred list heading. Label = compiled classifier output for the document.
Also checks which classifier output the claim's AFTER/BEFORE files are. Writes out/proxy1873.json."""
import re, json, os, collections, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v_shown_labels import roles, SP

VOLS = ["frus1873p1v1", "frus1873p1v2"]
MS = SP + "/reframe/measure-se-pocom"
LISTA = MS + "/classified/head-listvols-docs.jsonl"
LISTB = SP + "/chapter-context/label-validation/classified-list-volumes.jsonl"
HERE = os.path.dirname(os.path.abspath(__file__))

def strip(s):
    return " ".join(re.sub(r"<[^>]+>", "", s).split())

def load(path, key=lambda r: (r["volume"], r["d"])):
    out = {}
    for l in open(path):
        r = json.loads(l)
        if r["volume"] in VOLS:
            out[key(r)] = r
    return out

def entries(t):
    E = {}
    i = t.find('xml:id="correspondents"')
    if i < 0:
        return E
    j = t.find("<div", i + 10)
    sec = t[i:j if j > 0 else len(t)]
    heading = None
    for m in re.finditer(r'<p rend="center">(.*?)</p>|<item>(.*?)</item>', sec, re.S):
        if m.group(1) is not None:
            heading = strip(m.group(1)).lower().strip(" .")
        else:
            it = m.group(2)
            pm = re.search(r'<persName xml:id="([^"]+)">(.*?)</persName>', it, re.S)
            if pm:
                role = strip(it[pm.end():]).lstrip(" ,")
                E[pm.group(1)] = {"name": strip(pm.group(2)), "role": role, "heading": heading}
    return E

TOK = re.compile(r"<div\b([^>]*)>|</div>|<frus:attachment\b[^>]*>|</frus:attachment>|<head\b[^>]*>|</head>|<persName\b([^>]*)>(.*?)</persName>", re.S)

def mentions(t, vol):
    out, stack, heads, att, seen = [], [], [], 0, set()
    for m in TOK.finditer(t):
        g = m.group(0)
        if g.startswith("<div"):
            a = m.group(1)
            did = re.search(r'xml:id="([^"]+)"', a)
            stack.append(did.group(1) if ('type="document"' in a and did) else None)
        elif g == "</div>":
            stack and stack.pop()
        elif g.startswith("<frus:attachment"):
            att += 1
        elif g == "</frus:attachment>":
            att -= 1
        elif g.startswith("<head"):
            own = bool(stack) and stack[-1] is not None and stack[-1] not in seen and att == 0
            if own:
                seen.add(stack[-1])
            heads.append(own)
        elif g == "</head>":
            heads and heads.pop()
        elif g.startswith("<persName"):
            a = m.group(2) or ""
            ty = re.search(r'type="(from|to)"', a)
            if ty and heads and heads[-1] and stack and stack[-1]:
                c = re.search(r'corresp="#([^"]+)"', a)
                out.append({"v": vol, "d": stack[-1], "t": ty.group(1), "n": strip(m.group(3)), "link": c.group(1) if c else None})
    return out

FOREIGN = re.compile(r"majesty|of the king|of the emperor|emperor of|of the republic of|at washington|in the united states|minister (?:of|for) foreign|foreign affairs|of the (?:argentine|mexican|chilian|peruvian|brazilian)")
def evidence(e):
    role, head = e["role"].lower(), (e["heading"] or "")
    ev = set()
    foreign = bool(FOREIGN.search(role))
    if re.search(r"secretary of state|chief clerk", role) and not foreign:
        ev.add("department")
    if re.search(r"\bconsul", role) and not foreign:
        ev.add("us-consulate")
    if re.search(r"minister|envoy|charg|secretary of legation|legation|agent", role) and not foreign:
        ev.add("us-mission")
    if foreign:
        ev.add("foreign-legation")
    return ev

def main():
    R = {}
    A = load(SP + "/geo-fix/after-docs.jsonl"); B = load(SP + "/geo-fix/before-docs.jsonl")
    LA = load(LISTA); LB = load(LISTB)
    def same(x, y, fields):
        return sum(1 for k in x if k in y and all(json.dumps(x[k].get(f), sort_keys=True) == json.dumps(y[k].get(f), sort_keys=True) for f in fields))
    R["file_identity"] = {"after-docs 1873 docs": len(A), "head-listvols 1873 docs": len(LA),
                          "after==head-listvols on shown+chosenTitle+classifierByTitle": same(A, LA, ["shown", "chosenTitle", "classifierByTitle"]),
                          "before-docs 1873 docs": len(B), "label-validation list classify 1873 docs": len(LB),
                          "before-docs shown nonempty": sum(bool(r["shown"]) for r in B.values()),
                          "label-validation shown nonempty": sum(bool(r.get("shown")) for r in LB.values()),
                          "after-docs shown nonempty": sum(bool(r["shown"]) for r in A.values())}
    C = collections.defaultdict(collections.Counter)
    X = collections.defaultdict(list)
    ENT = {}
    for v in VOLS:
        t = open(f"/Users/jbotts/Development/frus/volumes/{v}.xml", encoding="utf-8").read()
        ENT[v] = entries(t)
        C["entries"][v] = len(ENT[v])
        for mm in mentions(t, v):
            C["head from/to"]["rows"] += 1
            e = ENT[v].get(mm["link"]) if mm["link"] else None
            if mm["link"] and e is None:
                for v2 in VOLS:
                    e = e or ENT.get(v2, {}).get(mm["link"])
                C["head from/to"]["link resolved in other volume" if e else "link unresolved"] += 1
            C["head from/to"]["linked"] += bool(e)
            for arm, D in (("after", A), ("before", B)):
                r = D.get((v, mm["d"]))
                if r is None:
                    C[arm]["no classifier record"] += 1
                    continue
                F, T = roles(r, "V1")
                own = F if mm["t"] == "from" else T
                kinds = {k for k, _ in own}
                C[arm]["labelled"] += bool(kinds)
                if not kinds:
                    continue
                if not e:
                    C[arm]["labelled, unlinked"] += 1
                    continue
                ev = evidence(e)
                if not ev:
                    C[arm]["labelled, evidence unparsed"] += 1
                    C[arm + ":unparsed label kinds"]["|".join(sorted(kinds))] += 1
                    continue
                ok = bool(kinds & ev)
                cls = "dept-only-evidence" if ev == {"department"} else "other-evidence"
                C[arm]["judged"] += 1
                C[arm]["right-kind"] += ok
                C[arm + ":" + cls]["judged"] += 1
                C[arm + ":" + cls]["right-kind"] += ok
                C[arm + ":by-label"]["|".join(sorted(kinds)) + (":right" if ok else ":wrong")] += 1
                C[arm + ":distinct entries"][cls + ":" + mm["link"]] = 1
                # place: label geo key vs list heading (shared 5-letter stem)
                if "department" not in kinds or len(kinds) > 1:
                    gk = {g for k, g in own if g}
                    hd = set(w[:5] for w in re.findall(r"[a-z]+", e["heading"] or ""))
                    place = "untestable" if not gk else ("shares-stem" if any(set(w[:5] for w in re.findall(r"[a-z]+", g)) & hd for g in gk) else "no-shared-stem")
                    C[arm + ":place (non-dept labels)"][place] += 1
                    if place == "no-shared-stem" and len(X["place"]) < 12:
                        X["place"].append([v + "/" + mm["d"], mm["n"], sorted(gk), e["heading"]])
                if not ok and len(X[arm]) < 10:
                    X[arm].append([v + "/" + mm["d"], mm["t"], mm["n"], e["role"][:80], e["heading"], sorted(kinds), r.get("header"), r.get("dateline")])
    for arm in ("after", "before"):
        k = arm + ":distinct entries"
        C[arm]["distinct entries judged (dept-only)"] = sum(1 for x in C[k] if x.startswith("dept-only"))
        C[arm]["distinct entries judged (other)"] = sum(1 for x in C[k] if x.startswith("other"))
        del C[k]
    R["counts"] = {k: dict(v) for k, v in C.items()}
    R["examples"] = X
    json.dump(R, open(os.path.join(HERE, "out", "proxy1873.json"), "w"), indent=1, sort_keys=True)
    print(json.dumps(R, indent=1, sort_keys=True))

if __name__ == "__main__":
    main()
