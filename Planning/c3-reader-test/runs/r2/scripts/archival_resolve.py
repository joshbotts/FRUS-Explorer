# Resolve the scope's two archival channels through the bundled JSON (never summed):
#   CAME-FROM  = out/arch_document_sources.tsv (document_sources rows of scope documents, one per document)
#   POINTED-AT = out/arch_external_citations.tsv (external_citations rows of scope documents, many per document)
# Decimal glosses come from decimal-class-labels.json and are GATED by the document's own year (coverage.glossableYears);
# subject-numeric glosses from subject-numeric-labels.json, gated the same way. Lots -> central-files-index.json lotFiles
# (lotNumber folded) -> series-facts-index.json byNaId (legend-decoded). Library collections -> presidential-library-catalog.json.
import csv, json, re
from collections import Counter, defaultdict
csv.field_size_limit(10**9)
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
DCL = json.load(open(R + "decimal-class-labels.json")); SNL = json.load(open(R + "subject-numeric-labels.json"))
CFI = json.load(open(R + "central-files-index.json")); SFI = json.load(open(R + "series-facts-index.json"))
PLC = json.load(open(R + "presidential-library-catalog.json")); LCI = json.load(open(R + "lot-claimants-index.json"))
CLR = json.load(open(R + "curated-lot-resolutions.json")); VSI = json.load(open(R + "volume-sources-index.json"))
scope = {(r["volume_id"], r["document_id"]): r for r in csv.DictReader(open("out/scope.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE)}
sched_by_id = {s["id"]: s for s in DCL["schedules"]}
def dec_sched(year):
    for g in DCL["coverage"]["glossableYears"]:
        if g["startYear"] <= year <= g["endYear"]: return sched_by_id[g["scheduleId"]]
    return None
def gloss_decimal(key, year):
    s = dec_sched(year)
    if not s: return None, "no-gloss (document year outside glossableYears)"
    m = re.match(r"^(\d)(\d\d[a-z]?)\.(\d\d[a-z]?)?(\S*)$", key)
    if not m: return None, "unparsed"
    cl, c1, rest1, rest2 = m.group(1), m.group(2), m.group(3) or "", m.group(4) or ""
    cls = s["classes"].get(cl); ctry = s["countries"].get(c1)
    if cl in s["relationsClasses"]:       # relations class: second country follows the point
        c2 = s["countries"].get(rest1) if rest1 else None
        g = f"{cls}: {ctry} – {c2}" if c2 else f"{cls}: {ctry}"
        if rest2: g += f" (subdivision {rest2} not glossed by the file)"
        return g, s["id"]
    subj = None
    if cl in s.get("subjects", {}):
        subs = s["subjects"][cl]; tail = (rest1 + rest2)
        for L in range(len(tail), 0, -1):
            if tail[:L] in subs: subj = subs[tail[:L]]; break
    g = f"{cls}: {ctry}" + (f" — {subj}" if subj else (f" (subject .{rest1}{rest2} not glossed by the file)" if (rest1 or rest2) else ""))
    return g, s["id"]
def gloss_snf(raw, year):
    sch = None
    for g in SNL["coverage"]["glossableYears"]:
        if g["startYear"] <= year <= g["endYear"]: sch = [x for x in SNL["schedules"] if x["id"] == g["scheduleId"]][0]
    m = re.search(r"\b([A-Z]{2,4})\s+(\d+(?:[-–]\d+)?)\s+([A-Z]+(?:[ -][A-Z]+)?)\b", raw)  # v3: en dash allowed; two-word areas (DOM REP)
    if m: m = type("M", (), {"group": (lambda self, i, _m=m: _m.group(i).replace("–", "-"))})()
    if not m:
        open("out/snf_unparsed.txt", "a").write(raw[:300] + "\n"); return None, None
    cat, num, area = m.group(1), m.group(2), m.group(3).strip()
    key = f"{cat} {num} {area}"
    if not sch: return key, "no-gloss (year outside glossableYears)"
    subj = sch["subjects"].get(cat, {}).get(num); ar = sch["areas"].get(area)
    return key, (f"{sch['categories'].get(cat, cat)} — {subj} — {ar}" if subj else f"no gloss for {cat} {num} in schedule {sch['id']}" + (f" (area {ar})" if ar else ""))
lots = defaultdict(list)
for r in CFI["lotFiles"]: lots[r["lotNumber"]].append(r)
claim = {r.get("lotNumber"): r for r in LCI["lots"]}
cur = {r.get("lotNumber"): r for r in CLR["lots"]}
L = SFI["legend"]["keys"]
def facts(naid):
    row = SFI["byNaId"].get(str(naid))
    if not row: return None
    out = {}
    for k, v in row.items():
        spec = L.get(k, {}); f = spec.get("field", k)
        if spec.get("kind") == "index": v = SFI[spec["into"]][v]
        elif spec.get("kind") == "indexList": v = [SFI[spec["into"]][i] for i in v]
        out[f] = v
    return out
def resolve_lot(norm):
    res = []
    for r in lots.get(norm, []):
        res.append({"naId": r.get("naId"), "title": r.get("title"), "recordGroup": r.get("recordGroup"),
                    "entry": r.get("hmsMlrEntryNumbers"), "matchType": r.get("matchType"), "facts": facts(r.get("naId"))})
    return res, (norm in claim), (norm in cur)
lib_by_cited = {l["citedAs"]: l for l in PLC["libraries"]}
def resolve_library(repo, series):
    lib = None
    for k, l in lib_by_cited.items():
        if repo and (repo.lower() in k.lower() or k.lower() in repo.lower()): lib = l
    if not lib or not series: return None
    s = series.lower()
    best = []
    for c in lib["collections"]:
        if c["title"].lower() == s or s in c["title"].lower(): best.append(("collection", c["title"], c.get("naId"), c.get("identifier"), None))
        for se in c.get("series", []):
            if se["title"].lower() == s: best.append(("series", f"{c['title']} > {se['title']}", se.get("naId"), c.get("identifier"), se.get("inclusiveDates")))
    return {"library": lib["citedAs"], "matches": best[:6]}
def year_of(v, d):
    dt = scope[(v, d)]["date_iso"]; return int(dt[:4]) if dt[:4].isdigit() else None
# ---------- CAME-FROM ----------
cf = list(csv.DictReader(open("out/arch_document_sources.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
units = Counter(); detail = {}; dec_docs = Counter(); dec_gl = {}
for r in cf:
    y = year_of(r["volume_id"], r["document_id"]); era = r["citation_era"]
    if era == "decimal" and r["decimal_class"]:
        key = r["decimal_class"]; g, sid = gloss_decimal(key, y or 0)
        u = f"RG 59 Central Decimal File | {key} | {g or sid}"
        units[u] += 1; dec_docs[key] += 1; dec_gl.setdefault(key, set()).add(g or sid)
    elif era == "subject_numeric":
        k, g = gloss_snf(r["raw_text"], y or 0); units[f"RG 59 Subject-Numeric File | {k} | {g}"] += 1
    elif era == "lot_file" and r["lot_file_norm"]:
        units[f"Lot file | {r['lot_file_norm']}"] += 1; detail[f"Lot file | {r['lot_file_norm']}"] = resolve_lot(r["lot_file_norm"])
    elif r["repository"] and ("Library" in r["repository"] or "Presidential" in r["repository"]):
        k = f"{r['repository']} | {r['series_name']}"; units[k] += 1; detail[k] = resolve_library(r["repository"], r["series_name"])
    else:
        units[f"{era} | {r['repository']} | {r['record_group']} | {r['series_name'][:60]}"] += 1
json.dump({"units": units.most_common(), "detail": detail, "decimal_docs": dec_docs.most_common(), "decimal_gloss": {k: sorted(v) for k, v in dec_gl.items()}},
          open("out/archival_camefrom.json", "w"), indent=1, default=str)
nodoc = [k for k in scope if k not in {(r["volume_id"], r["document_id"]) for r in cf}]
per = Counter(("<=1905" if int(scope[k]["date_iso"][:4]) <= 1905 else ("1906-1909" if int(scope[k]["date_iso"][:4]) <= 1909 else ">=1910")) for k in nodoc)
print(f"CAME-FROM: {len(cf)} of {len(scope)} scope documents carry a source row; {len(nodoc)} carry none, by date: {dict(per)}")
print("Top came-from units (documents):")
for u, n in units.most_common(30): print(f"  {n:4d}  {u}")
open("out/archival_camefrom_units.tsv", "w").write("".join(f"{n}\t{u}\n" for u, n in units.most_common()))
# ---------- POINTED-AT ----------
pa = list(csv.DictReader(open("out/arch_external_citations.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
punits = Counter(); pdocs = defaultdict(set); pdetail = {}
for r in pa:
    y = year_of(r["volume_id"], r["document_id"])
    if r["anchor"] == "centralFileClass" and r["decimal_class"]:
        g, sid = gloss_decimal(r["decimal_class"], y or 0); k = f"Central Decimal File class | {r['decimal_class']} | {g or sid}"
    elif r["anchor"] == "lotFile":
        k = f"Lot file | {r['lot_file_norm']}"; pdetail[k] = resolve_lot(r["lot_file_norm"])
    else:
        k = f"Library | {r['repository']} | {r['collection']}"; pdetail[k] = resolve_library(r["repository"], r["collection"])
    punits[k] += 1; pdocs[k].add((r["volume_id"], r["document_id"]))
json.dump({"units": [(k, n, len(pdocs[k])) for k, n in punits.most_common()], "detail": pdetail}, open("out/archival_pointedat.json", "w"), indent=1, default=str)
print(f"\nPOINTED-AT: {len(pa)} citation rows on {len({(r['volume_id'], r['document_id']) for r in pa})} scope documents; earliest cited-from document date:",
      min(scope[(r['volume_id'], r['document_id'])]['date_iso'] for r in pa))
for k, n in punits.most_common(30): print(f"  {n:3d} rows / {len(pdocs[k]):3d} docs  {k}")
