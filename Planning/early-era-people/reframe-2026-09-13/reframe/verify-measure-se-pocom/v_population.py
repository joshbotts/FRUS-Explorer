#!/usr/bin/env python3
"""VERIFIER script 1 (independent of measure-se-pocom code): row population, head grain from the TEI, POCOM surname rule.

Inputs (read-only): ~/frus-ner-raw/scope.json + marked/, /Users/jbotts/Development/frus/volumes/<vol>.xml,
/Users/jbotts/Development/pocom (people/, missions-*/, positions-principals/), parsed with ElementTree.
Head grain: each marked row is aligned (in-document order, type + whitespace-collapsed surface) to the TEI
<persName> sequence of its document; a row is HEAD when its TEI element sits inside the document div's own <head>.
POCOM rule (m1a definition, re-typed here): surname = last capitalised token of >=3 chars not in the title list;
candidates = POCOM people with that surname and at least one dated chief/principal appointment; live = any
appointment year span [min,max] with min-1 <= doc year <= max+1 (doc year = TEI frus:doc-dateTime-min).
Writes out/population.json and out/rows-verify.jsonl.gz.
"""
import os, re, json, gzip, glob, collections
import xml.etree.ElementTree as ET

HOME = os.path.expanduser("~")
STORE = HOME + "/frus-ner-raw"
VOLS = "/Users/jbotts/Development/frus/volumes"
POCOM = "/Users/jbotts/Development/pocom"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
TITLES = {"Mr.", "Mrs.", "Sir", "Lord", "Count", "Baron", "Prince", "King", "Queen", "Excellency", "Dr.", "Hon."}

def ws(s):
    return " ".join(s.split())

def surname(name):
    toks = [t.strip(".,;:()") for t in name.split()]
    toks = [t for t in toks if t and t not in TITLES and t[0].isupper() and len(t) >= 3]
    return toks[-1] if toks else None

def load_pocom():
    sur = {}
    for p in glob.glob(POCOM + "/people/*/*.xml"):
        root = ET.parse(p).getroot()
        pid = root.findtext("id")
        s = root.findtext(".//surname")
        if pid and s and s.strip():
            sur[pid.strip()] = s.strip()
    spans = collections.defaultdict(list)
    files = glob.glob(POCOM + "/missions-countries/*.xml") + glob.glob(POCOM + "/missions-orgs/*.xml") + glob.glob(POCOM + "/positions-principals/*.xml")
    for p in files:
        root = ET.parse(p).getroot()
        for el in root.iter():
            if el.tag not in ("chief", "principal"):
                continue
            pid = el.findtext("person-id")
            if not pid:
                continue
            ys = [int(d.text.strip()[:4]) for d in el.iter("date") if d.text and re.match(r"\s*\d{4}", d.text)]
            if ys:
                spans[pid.strip()].append((min(ys), max(ys)))
    by = collections.defaultdict(set)
    for pid, s in sur.items():
        if pid in spans:
            by[s].add(pid)
    return sur, spans, by

TOK = re.compile(r"<div\b([^>]*)>|</div>|<frus:attachment\b[^>]*>|</frus:attachment>|<head\b[^>]*>|</head>|<persName\b([^>]*)>(.*?)</persName>", re.S)
TYPE = re.compile(r'\btype="([^"]*)"')

def tei_docs(vol):
    t = open(f"{VOLS}/{vol}.xml", encoding="utf-8").read()
    docs = {}
    stack = []           # (divtype, docid)
    headdepth = 0
    headowner = []       # True when the open head is the document's own
    attach_depth = 0
    for m in TOK.finditer(t):
        g = m.group(0)
        if g.startswith("<div"):
            attrs = m.group(1)
            ty = TYPE.search(attrs)
            did = re.search(r'xml:id="([^"]+)"', attrs)
            ty = ty.group(1) if ty else None
            docid = did.group(1) if (ty == "document" and did) else None
            if docid:
                y = re.search(r'frus:doc-dateTime-min="(\d{4})', attrs)
                docs[docid] = {"year": int(y.group(1)) if y else None, "p": []}
            stack.append((ty, docid))
        elif g == "</div>":
            if stack:
                stack.pop()
        elif g.startswith("<head"):
            # the document's OWN head = the first <head> opened while the document div is on top of the stack
            own = False
            if stack and stack[-1][1] and not docs[stack[-1][1]].get("headseen") and attach_depth == 0:
                docs[stack[-1][1]]["headseen"] = True
                own = True
            headowner.append(own)
        elif g == "</head>":
            if headowner:
                headowner.pop()
        elif g.startswith("<frus:attachment"):
            attach_depth += 1
        elif g == "</frus:attachment>":
            attach_depth -= 1
        else:
            # innermost enclosing document div
            cur = None
            for ty, docid in reversed(stack):
                if docid:
                    cur = docid
                    break
            if cur is None:
                continue
            ty = TYPE.search(m.group(2))
            # in the document's OWN head: a head is open whose owner depth is the depth where the doc div is top
            in_head = bool(headowner) and headowner[-1] is True and stack[-1][1] == cur
            docs[cur]["p"].append((ty.group(1) if ty else None, ws(re.sub(r"<[^>]+>", "", m.group(3))), in_head))
    return docs

def band(vol):
    y = int(vol[4:8])
    return "1861-1899" if y <= 1899 else ("1900-1905" if y <= 1905 else None)

def main():
    scope = json.load(open(STORE + "/scope.json"))["volumes"]
    vols = [v for v in scope if band(v)]
    sur, spans, by = load_pocom()
    C = collections.defaultdict(collections.Counter)
    DOCS = collections.defaultdict(set)
    VOLN = collections.Counter()
    out = gzip.open(os.path.join(OUT, "rows-verify.jsonl.gz"), "wt")
    for v in vols:
        b = band(v)
        VOLN[b] += 1
        td = tei_docs(v)
        rows = [json.loads(l) for l in gzip.open(f"{STORE}/marked/{v}.jsonl.gz", "rt")]
        bydoc = collections.defaultdict(list)
        for r in rows:
            bydoc[r["d"]].append(r)
        for d, rs in bydoc.items():
            rs.sort(key=lambda r: (r["s"], r["e"]))
            seq = td.get(d, {"p": [], "year": None})
            ps = seq["p"]
            j = 0
            for r in rs:
                k = j
                hit = None
                while k < len(ps):
                    if ps[k][1] == ws(r["n"]) and ps[k][0] == r["t"]:
                        hit = k
                        break
                    k += 1
                if hit is None:
                    grain = "unaligned"
                else:
                    grain = "head" if ps[hit][2] else "non-head"
                    j = hit + 1
                if r["t"] not in ("from", "to"):
                    continue
                C[b]["rows"] += 1
                C[b]["grain:" + grain] += 1
                DOCS[b].add((v, d))
                s = surname(ws(re.sub(r"<[^>]+>", "", r["n"])))
                cands = by.get(s) if s else None
                yr = seq["year"]
                if not cands:
                    pc, ps1 = "unknown", None
                elif yr is None:
                    pc, ps1 = "undated", None
                else:
                    live = sorted(p for p in cands if any(a - 1 <= yr <= z + 1 for a, z in spans[p]))
                    pc = {0: "nobody", 1: "one"}.get(len(live), "several")
                    ps1 = live[0] if len(live) == 1 else None
                C[b]["pocom:" + pc] += 1
                if grain == "head":
                    C[b]["head:pocom:" + pc] += 1
                out.write(json.dumps({"v": v, "d": d, "t": r["t"], "s": r["s"], "e": r["e"], "n": r["n"], "band": b,
                                      "grain": grain, "sur": s, "pocom": pc, "pslug": ps1, "year": yr}) + "\n")
    out.close()
    res = {b: dict(C[b]) | {"docs_holding_rows": len(DOCS[b]), "volumes": VOLN[b]} for b in C}
    res["pocom_people_with_surname"] = len(sur)
    res["pocom_people_with_spans"] = len(spans)
    json.dump(res, open(os.path.join(OUT, "population.json"), "w"), indent=1, sort_keys=True)
    print(json.dumps(res, indent=1, sort_keys=True))

if __name__ == "__main__":
    main()
