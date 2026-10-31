# Refuter check of the archival identifiers the bottom line's second paragraph names, against the bundled artifacts.
import json, re, sqlite3
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c = sqlite3.connect(DB, uri=True)
cf = json.load(open(RES + "central-files-index.json"))
sf = json.load(open(RES + "series-facts-index.json"))
ca = json.load(open(RES + "collection-authority.json"))
print("central-files-index keys:", list(cf.keys()))
print("series-facts keys:", list(sf.keys()))
print("collection-authority keys:", list(ca.keys()) if isinstance(ca, dict) else type(ca))
L = sf['legend']['keys']
def facts(naid):
    r = sf['byNaId'].get(str(naid))
    if not r: return None
    o = {}
    for k, v in r.items():
        spec = L.get(k)
        if not spec: o[k] = v; continue
        if spec['kind'] == 'index': o[spec['field']] = sf[spec['into']][v]
        elif spec['kind'] == 'indexList': o[spec['field']] = [sf[spec['into']][i] for i in v]
        else: o[spec['field']] = v
    return o
print("legend fields:", sorted(set(s.get('field', k) for k, s in L.items())))
lots = {}
for row in cf['lotFiles']:
    lots.setdefault(re.sub(r'\s+', '', row['lotNumber']), []).append(row)
print("lotFiles rows:", len(cf['lotFiles']), "distinct lots:", len(lots))
print("sample lotFiles row keys:", list(cf['lotFiles'][0].keys()))

CLAIMS = [
    ("62 D 430", {"rg": "59", "entry": "A1 1586C", "naid": "2839191", "title": "Subject and Special Files", "dates": (1953, 1961), "access": "Restricted - Partly", "creator": "Executive Secretariat"}),
    ("63 D 351", {"rg": "59", "entry": "A1 1586E", "naid": "2839192", "title": "National Security Council Policy Papers", "dates": (1947, 1979), "access": "Restricted - Partly"}),
    ("67 D 54", {"rg": "59", "entry": "A1 5305/A1 5414", "naid": "631403", "title": "Subject Files of the Vietnam Working Group", "dates": (1963, 1974), "access": "Unrestricted"}),
    ("66 D 95", {"rg": "59", "entry": "A1 1586E", "naid": "2839192", "title": "National Security Council Policy Papers", "dates": (1947, 1979), "access": "Restricted - Partly"}),
    ("59 D 260", {"rg": "306", "naid": "1257679", "title": "Subject Files", "dates": (1953, 1971), "access": "Restricted - Partly", "extent": "47 linear feet", "creator": "Office of Policy and Plans"}),
    ("65 D 101", {"rg": "59", "naid": "1136548", "title": "Chronological Files", "dates": (1947, 1962), "access": "Unrestricted", "creator": "Policy Planning Council"}),
    ("63 D 224", {"absent": True}), ("62 D 255", {"absent": True}), ("60 D 322", {"absent": True}),
]
for lot, cl in CLAIMS:
    key = lot.replace(" ", "")
    rows = lots.get(key, [])
    print(f"\n--- Lot {lot}: lotFiles rows {len(rows)}")
    if cl.get("absent"):
        print("   claim: bundled data cannot place it ->", "CONFIRMED absent from lotFiles" if not rows else f"PRESENT: {rows}")
        continue
    for row in rows:
        f = facts(row.get('naId'))
        print("   row:", {k: row.get(k) for k in ('recordGroup', 'naId', 'hmsMlrEntryNumbers', 'title', 'matchType', 'lotNumber')})
        if f: print("   facts:", {k: f.get(k) for k in ('creator', 'inclusiveStartYear', 'inclusiveEndYear', 'accessStatus', 'useStatus', 'extent', 'accessRestrictions', 'title')})
        checks = {
            'rg': str(row.get('recordGroup')) == cl['rg'],
            'naid': str(row.get('naId')) == cl['naid'],
            'title': cl['title'].lower() in str(row.get('title', '')).lower(),
            'dates': f is not None and (f.get('inclusiveStartYear'), f.get('inclusiveEndYear')) == cl['dates'],
            'access': f is not None and str(f.get('accessStatus')).startswith(cl['access']),
        }
        if 'entry' in cl: checks['entry'] = all(e.strip() in (row.get('hmsMlrEntryNumbers') or []) for e in cl['entry'].split('/'))
        if 'extent' in cl: checks['extent'] = f is not None and f.get('extent') == cl['extent']
        if 'creator' in cl: checks['creator'] = f is not None and cl['creator'] in str(f.get('creator'))
        print("   checks:", checks, "ALL OK" if all(checks.values()) else "MISMATCH")

# RG 306 named series in collection-authority
print("\n--- collection-authority: RG 306 series the overview names (and whether they carry a NAID)")
def walk(o):
    if isinstance(o, dict):
        yield o
        for v in o.values(): yield from walk(v)
    elif isinstance(o, list):
        for v in o: yield from walk(v)
NEEDLES = ["Director’s Subject Files", "Director's Subject Files", "Joint U.S. Public Affairs Office", "JUSPAO", "DIRCTR", "Office of Policy and Plans", "Office of Research", "P–207", "P-207", "A1–42", "A1-42", "A1–31", "A1-31", "UD WW 257", "UD–UP 7"]
seen = 0
for o in walk(ca):
    s = json.dumps(o, ensure_ascii=False)
    if len(s) > 3000: continue
    if any(n in s for n in NEEDLES) and ('306' in s or 'Information Agency' in s or 'USIA' in s):
        seen += 1
        if seen <= 40: print("  ", s[:400])
print("  matching nodes:", seen)

print("\n--- series-facts: rows whose creator names the Information Agency, and any Office of Research / East Asia")
for naid in sf['byNaId']:
    f = facts(naid); cr = str(f.get('creator', ''))
    if 'Information Agency' in cr:
        print("  ", naid, cr, f.get('inclusiveStartYear'), f.get('inclusiveEndYear'), f.get('accessStatus'), f.get('title'))

print("\n--- external_citations raw text for frus1955-57v09/d207 (the source of 59 D 260, 63 D 224, 62 D 255, 60 D 322):")
for r in c.execute("SELECT lot_file_norm, repository, anchor, substr(raw_text,1,260) FROM external_citations WHERE volume_id='frus1955-57v09' AND document_id='d207'"):
    print("  ", r)
print("\n--- which candidate-set documents point at 65 D 101 and 66 D 95 and 63 D 351:")
cand = [tuple(l.strip().split("|")) for l in open("/Users/jbotts/frus-analysis/c3f/runs/f9/candidate_set.txt") if l.strip()]
for lot in ('65D101', '66D95', '63D351', '62D430', '71D273', '60D627', '67D54'):
    docs = []
    for v, d in cand:
        n = c.execute("SELECT COUNT(*) FROM external_citations WHERE volume_id=? AND document_id=? AND lot_file_norm=?", (v, d, lot)).fetchone()[0]
        if n: docs.append((v, d, n))
    print("  ", lot, "rows:", sum(n for _, _, n in docs), "docs:", docs)
print("\n--- document_sources of the 25: record group / series / era")
pairs = [tuple(l.split()) for l in open("/Users/jbotts/frus-analysis/c3f/runs/f9/collection_pairs.txt") if l.strip()]
import collections
cnt = collections.Counter()
for v, d in pairs:
    r = c.execute("SELECT repository, record_group, lot_file_norm, series_name, citation_era FROM document_sources WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    cnt[(r[0], r[1], r[4] if r[4] in ('decimal', 'cfpf', 'lot_file') else r[3])] += 1
for k, n in cnt.most_common(): print("  ", n, k)
