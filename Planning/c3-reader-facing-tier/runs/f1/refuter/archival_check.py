#!/usr/bin/env python3
"""Refuter check of the archival identifiers in the overview's bottom-line ¶2 against the bundled artifacts and the index."""
import json, re, sqlite3
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f1"
c = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
ci = json.load(open(R + "central-files-index.json"))
sf = json.load(open(R + "series-facts-index.json"))
ca = json.load(open(R + "collection-authority.json"))
plc = json.load(open(R + "presidential-library-catalog.json"))
eci = json.load(open(R + "external-citation-index.json"))
vsi = json.load(open(R + "volume-sources-index.json"))
clr = json.load(open(R + "curated-lot-resolutions.json"))
lci = json.load(open(R + "lot-claimants-index.json"))
dcl = json.load(open(R + "decimal-class-labels.json"))

print("central-files-index keys:", list(ci.keys()))
print("series-facts keys:", list(sf.keys()), "legend:", json.dumps(sf.get('legend'))[:600])

def facts(na):
    r = sf['byNaId'].get(str(na))
    if not r: return None
    g = lambda k, arr: sf[arr][r[k]] if k in r else None
    return dict(raw=r, creator=g('c', 'headings'), y0=r.get('y0'), y1=r.get('y1'), extent=r.get('x'),
                access=g('as', 'statuses'), use=g('us', 'statuses'), ref=g('ru', 'referenceUnits'))

print("\n=== Lots via central-files-index lotFiles ===")
for lot in ['63D351', '66D95', '62D333', '67D54', '58D726', '61D385', '62D430', '62D1']:
    rows = [x for x in ci['lotFiles'] if x.get('lotNumber') == lot]
    if not rows:
        print(lot, "-> NOT IN central-files-index lotFiles")
        continue
    for x in rows:
        print(lot, "->", {k: x.get(k) for k in ('recordGroup', 'hmsMlrEntryNumbers', 'naId', 'title', 'matchType', 'dateRange', 'inclusiveDates') if k in x}, "| facts:", facts(x['naId']))
print("\nlotFiles row keys:", list(ci['lotFiles'][0].keys()))

print("\n=== 61D385 elsewhere ===")
s = json.dumps(clr); print("61D385 or '61 D 385' in curated-lot-resolutions:", bool(re.search(r'61\s?D\s?385', s)))
s = json.dumps(lci); print("61D385 in lot-claimants-index:", bool(re.search(r'61\s?D\s?385', s)))
s = json.dumps(ca); print("61D385 in collection-authority:", bool(re.search(r'61\s?D\s?385', s)))
s = json.dumps(vsi); print("61D385 in volume-sources-index:", bool(re.search(r'61\s?D\s?385', s)))
s = json.dumps(eci); print("61D385 in external-citation-index:", bool(re.search(r'61\s?D\s?385', s)))
print("61D385 rows in index document_sources:", c.execute("SELECT COUNT(*) FROM document_sources WHERE lot_file_norm='61D385'").fetchone(),
      "external_citations:", c.execute("SELECT COUNT(*) FROM external_citations WHERE lot_file_norm='61D385'").fetchone())

print("\n=== Series facts for the four NAIDs ===")
for na in ['2839192', '2124692', '631403', '2544398', '40967285']:
    print(na, facts(na))

print("\n=== RG 306 in collection-authority.json ===")
print("collection-authority keys:", list(ca.keys()) if isinstance(ca, dict) else type(ca))
recs = ca.get('records') or ca.get('collections') or ca
if isinstance(recs, dict):
    for k in list(recs.keys())[:3]: print("  sample key", k, json.dumps(recs[k])[:300])
else:
    print("  sample", json.dumps(recs[0])[:400])
blob = json.dumps(ca)
for pat in [r"Director.s Subject Files", r"DIRCTR", r"Entry A1.42", r"UD WW 257", r"UD WW 193", r"P.207", r"P.104", r"67 A 222", r"68 A 4933", r"Office of Policy and Plans"]:
    print(f"  {pat!r} in collection-authority: {bool(re.search(pat, blob))}")
# records mentioning RG 306 / Director's Subject Files with naId
def walk(o, path=""):
    if isinstance(o, dict):
        txt = json.dumps(o)
        if re.search(r"Director.s Subject Files|DIRCTR", txt) and len(txt) < 3000:
            yield o
        for k, v in o.items():
            yield from walk(v, path + "/" + str(k))
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from walk(v, path + f"[{i}]")
seen = 0
for o in walk(ca):
    if seen >= 8: break
    print("  CA record:", json.dumps(o)[:350]); seen += 1

print("\n=== Presidential library NSF collections in presidential-library-catalog.json ===")
print("plc keys:", list(plc.keys()) if isinstance(plc, dict) else type(plc))
blob = json.dumps(plc)
for pat in [r"Kennedy", r"National Security Files", r"Johnson", r"National Security File", r"Nixon", r"NSC Files"]:
    print(f"  {pat!r} in presidential-library-catalog: {bool(re.search(pat, blob))} ({len(re.findall(pat, blob))})")

print("\n=== Decimal class gloss (decimal-class-labels.json) ===")
print("dcl keys:", list(dcl.keys()))
print("coverage:", json.dumps(dcl.get('coverage'))[:400])
sch = dcl.get('schedules') or {}
print("schedules:", list(sch.keys()) if isinstance(sch, dict) else type(sch))
blob = json.dumps(dcl)
for pat in ['International Informational and Educational Relations', '"United States"', 'Far East \\(including all of Asia\\)', 'World, The', 'Indo China', '"Asia"']:
    print(f"  {pat!r}: {len(re.findall(pat, blob))} occurrences")
s5059 = sch.get('1950-1959') if isinstance(sch, dict) else None
if s5059:
    print("  1950-1959 schedule keys:", list(s5059.keys()))
    for k in s5059:
        v = s5059[k]
        if isinstance(v, dict):
            for kk in ['5', '11', '90', '00', '51G']:
                if kk in v: print(f"   {k}[{kk}] = {json.dumps(v[kk])[:200]}")

print("\n=== external-citation-index.json: 511.90 / 511.00 ===")
print("eci keys:", list(eci.keys()) if isinstance(eci, dict) else type(eci))
blob = json.dumps(eci)
for pat in ['511.90', '511.00', '"511"']:
    print(f"  {pat!r}: {len(re.findall(re.escape(pat), blob))} occurrences")

print("\n=== Index rows for the 22: entries and accessions in source notes ===")
import csv
argset = [tuple(r) for r in csv.reader(open(RUN + "/argset.csv"))]
pats = {'Entry A1–42': r'Entry A1.42', 'Entry UD WW 257': r'Entry UD WW 257', 'Entry UD WW 193': r'Entry UD WW 193', 'Entry P–207': r'Entry P.207',
        'Entry P–104': r'Entry P.104', 'FRC 67 A 222': r'FRC 67 A 222', 'FRC 68 A 4933': r'FRC 68 A 4933', 'RG 306': r'RG 306', 'Kennedy NSF': r'Kennedy Library, National Security Files',
        'Johnson NSF': r'Johnson Library, National Security File', 'Nixon NSC': r'Nixon Presidential Materials, NSC Files', 'Lot 63 D 351': r'Lot 63 D 351', 'Lot 61 D 385': r'Lot 61 D 385'}
for v, d in argset:
    sn = c.execute("SELECT source_note FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()[0] or ''
    hits = [k for k, p in pats.items() if re.search(p, sn)]
    print(f"  {v}/{d}: {hits} :: {sn[:110]!r}")
print("\nexternal_citations rows for the 22 (anchor, lot, decimal_class, raw):")
for r in c.execute("SELECT ec.volume_id||'/'||ec.document_id, ec.anchor, ec.lot_file_norm, ec.decimal_class, substr(ec.raw_text,1,70) FROM external_citations ec WHERE (ec.volume_id,ec.document_id) IN (VALUES " + ",".join(f"('{v}','{d}')" for v, d in argset) + ") ORDER BY 1"):
    print("  ", r)
print("\ndocument_sources decimal rows for the 22:")
for r in c.execute("SELECT ds.volume_id||'/'||ds.document_id, ds.citation_era, ds.decimal_class, ds.series_name FROM document_sources ds WHERE (ds.volume_id,ds.document_id) IN (VALUES " + ",".join(f"('{v}','{d}')" for v, d in argset) + ") AND ds.citation_era='decimal'"):
    print("  ", r)

print("\n=== central-files-index: any series with naId for the 1950-59 decimal file? ===")
for k in ci:
    if k == 'lotFiles': continue
    v = ci[k]
    print(f"  {k}: {type(v).__name__} {len(v) if hasattr(v,'__len__') else ''} :: {json.dumps(v)[:300]}")
