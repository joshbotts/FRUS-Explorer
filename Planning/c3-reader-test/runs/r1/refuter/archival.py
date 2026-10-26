#!/usr/bin/env python3 -I
"""Refuter: confirm every archival identifier named in the overview's bottom line, paragraph 2
(and the Reagan Library ones in paragraph 3d) against the bundled JSON files, by a recursive
search for the identifier as a leaf value, printing the dict that holds it."""
import json, re, os, sys
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
FILES = ["collection-authority.json", "central-files-index.json", "volume-sources-index.json",
         "presidential-library-catalog.json", "external-citation-index.json", "series-facts-index.json",
         "lot-claimants-index.json", "curated-library-resolutions.json", "curated-lot-resolutions.json",
         "subject-numeric-labels.json", "decimal-class-labels.json", "accession-series-index.json", "roll-scans-index.json"]

NAIDS = {"1151288": "lot 64 D 563 -> Numbered Staff Studies (PPS)", "2198167": "lot 62 D 1 -> Alphabetical Files",
         "2838991": "lot 62 D 1 -> Numerical Files", "2838992": "lot 62 D 1 -> Records Relating to Activities with the NSC",
         "1164": "Kennedy Library NSF collection", "193236": "Kennedy NSF Country Files", "567979": "Johnson Library NSF collection",
         "567985": "Johnson NSF Latin America Country Files", "572247": "Nixon NSF Institutional Files", "572235": "Nixon NSF collection",
         "593313": "Diplomatic Instructions series", "149324017": "Instructions roll Mexico 1873-79", "149302787": "Instructions roll Colombia 1898-1906",
         "603720": "Diplomatic Despatches series", "2108779": "lots 59 D 573 / 61 D 279 -> Rubottom subject files", "2363840": "lot 63 D 127 -> ARA/OAP",
         "1750062": "lot 64 D 16 -> El Salvador records", "26309336": "lot 70 D 247 -> Ecuador subject files", "12024796": "Reagan NSC Latin American Affairs Directorate",
         "654171": "Numerical File microfilm series", "1191": "Reagan WHORM collection", "6207697": "WHORM Subject Files South America, Central and Latin America"}
LOTS = {"64 D 563": r"64\s*[-–]?\s*D\s*[-–]?\s*563(?!\d)", "62 D 1": r"(?<!\d)62\s*[-–]?\s*D\s*[-–]?\s*1(?![\d])", "59 D 573": r"59\s*[-–]?\s*D\s*[-–]?\s*573(?!\d)",
        "61 D 279": r"61\s*[-–]?\s*D\s*[-–]?\s*279(?!\d)", "63 D 127": r"63\s*[-–]?\s*D\s*[-–]?\s*127(?!\d)", "64 D 16": r"64\s*[-–]?\s*D\s*[-–]?\s*16(?!\d)", "70 D 247": r"70\s*[-–]?\s*D\s*[-–]?\s*247(?!\d)"}
ENTRIES = ["A1 558-A", "A1 1583A", "A1 1583B", "A1 1583C", "A1 1583D", "A1 1583E", "A1 1583F", "A1 1135", "A1 3157", "A1 3159", "A1 5741"]
def normE(s): return re.sub(r"[\s\-–]", "", s).upper()
ENTRIES_N = {normE(e): e for e in ENTRIES}

def scal(d, lim=700):
    out = {k: v for k, v in d.items() if not isinstance(v, (dict, list))}
    s = json.dumps(out, ensure_ascii=False)
    return s[:lim] + ("..." if len(s) > lim else "")

hits = {}
def walk(node, path, fname, parent=None):
    if isinstance(node, dict):
        for k, v in node.items():
            walk(v, path + "/" + str(k), fname, node)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk(v, path + f"[{i}]", fname, parent if not isinstance(v, (dict, list)) else node)
    else:
        sv = str(node)
        for n in NAIDS:
            if sv == n:
                key = (fname, "NAID " + n)
                hits.setdefault(key, [])
                if len(hits[key]) < 4: hits[key].append((path, scal(parent) if isinstance(parent, dict) else sv))
        if isinstance(node, str):
            for lot, rx in LOTS.items():
                if re.search(rx, node, re.I):
                    key = (fname, "LOT " + lot)
                    hits.setdefault(key, [])
                    if len(hits[key]) < 4: hits[key].append((path, scal(parent) if isinstance(parent, dict) else sv))
            ne = normE(node)
            for en, e in ENTRIES_N.items():
                if ne == en or re.search(r"(?<![A-Z0-9])" + re.escape(en) + r"(?![A-Z0-9])", ne):
                    key = (fname, "ENTRY " + e)
                    hits.setdefault(key, [])
                    if len(hits[key]) < 4: hits[key].append((path, scal(parent) if isinstance(parent, dict) else sv))
            if re.search(r"clean\s*-?\s*up", node, re.I) and fname in ("presidential-library-catalog.json", "curated-library-resolutions.json"):
                key = (fname, "TEXT Clean Up")
                hits.setdefault(key, [])
                if len(hits[key]) < 4: hits[key].append((path, scal(parent) if isinstance(parent, dict) else sv))

for fn in FILES:
    p = os.path.join(RES, fn)
    sz = os.path.getsize(p)
    data = json.load(open(p))
    top = list(data.keys())[:25] if isinstance(data, dict) else f"list[{len(data)}]"
    print(f"\n##### {fn} ({sz/1e6:.1f} MB) top: {top}")
    walk(data, "", fn)
    sys.stdout.flush()

print("\n\n================ HITS ================")
for key in sorted(hits):
    print(f"\n--- {key[0]} :: {key[1]}  ({NAIDS.get(key[1].replace('NAID ',''), '')})")
    for path, s in hits[key]:
        print(f"   {path}\n      {s}")
print("\n--- identifiers with NO hit in any file:")
found = {k[1] for k in hits}
for n, what in NAIDS.items():
    if "NAID " + n not in found: print("   NAID", n, what)
for lot in LOTS:
    if "LOT " + lot not in found: print("   LOT", lot)
for e in ENTRIES:
    if "ENTRY " + e not in found: print("   ENTRY", e)
if not any(k[1] == "TEXT Clean Up" for k in hits): print("   'Clean Up' appears in neither presidential-library-catalog.json nor curated-library-resolutions.json (the overview's negative claim holds)")

# subject-numeric labels
sn = json.load(open(os.path.join(RES, "subject-numeric-labels.json")))
print("\n##### subject-numeric-labels.json keys:", list(sn.keys())[:20] if isinstance(sn, dict) else type(sn))
txt = json.dumps(sn, ensure_ascii=False)
for code in ["POL 16", "POL 26", "POL 23-9", "POL 23"]:
    for m in list(re.finditer(re.escape('"' + code + '"'), txt))[:3]:
        print(f"   {code}: ...{txt[max(0,m.start()-150):m.end()+200]}...")
# decimal file: does central-files-index.json carry a NAID/entry/access for the central decimal file?
cf = json.load(open(os.path.join(RES, "central-files-index.json")))
print("\n##### central-files-index.json keys:", list(cf.keys()) if isinstance(cf, dict) else type(cf))
for k in cf:
    v = cf[k]
    if isinstance(v, dict):
        print(f"   {k}: dict keys {list(v.keys())[:12]}")
    elif isinstance(v, list):
        print(f"   {k}: list[{len(v)}] first: {json.dumps(v[0], ensure_ascii=False)[:300] if v else ''}")
    else:
        print(f"   {k}: {str(v)[:200]}")
dtxt = json.dumps({k: v for k, v in cf.items() if 'decimal' in k.lower()}, ensure_ascii=False)
print("   decimal-named keys content (first 1500):", dtxt[:1500])
