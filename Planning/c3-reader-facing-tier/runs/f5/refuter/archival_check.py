# archival_check.py: every identifier the bottom line's second paragraph names, against the bundled JSON and the index.
import json, re, sqlite3, collections
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c = sqlite3.connect(DB, uri=True)
cf = json.load(open(R + "central-files-index.json"))
sf = json.load(open(R + "series-facts-index.json"))
acc = json.load(open(R + "accession-series-index.json"))
print("central-files keys:", list(cf.keys()))
lots = cf['lotFiles'] if isinstance(cf.get('lotFiles'), list) else cf.get('lotFiles')
print("lotFiles rows:", len(lots), "sample:", lots[0])
by = sf['byNaId']; leg = sf['legend']['keys']
statuses = sf['statuses'] if 'statuses' in sf else None
print("series-facts top-level:", list(sf.keys()))
def facts(naid):
    r = by.get(str(naid))
    if not r: return None
    out = {}
    for k, v in r.items():
        f = leg.get(k, {}).get('field', k); kind = leg.get(k, {}).get('kind'); into = leg.get(k, {}).get('into')
        if kind == 'index': out[f] = sf[into][v]
        elif kind == 'indexList': out[f] = [sf[into][i] for i in v]
        else: out[f] = v
    return out

def lot(l):
    k = re.sub(r'\s+', '', l)
    return [x for x in lots if re.sub(r'\s+', '', x.get('lotNumber', '')) == k]

checked = []
def rec(name, ok, detail):
    checked.append((name, ok, detail)); print(f"  {'CONFIRMED' if ok else 'NOT CONFIRMED'}: {name} -- {detail}")

print("\n== lot files named in the overview ==")
for l, naid, entries, years, title in [("61 D 167", "2198167", ["A1 1583A", "A1 1583B"], (1948, 1961), "Alphabetical Files"),
                                        ("63 D 351", "2839192", ["A1 1586E"], (1947, 1979), "Records Relating to National Security Council Policy Papers"),
                                        ("62 D 430", "2839191", ["A1 1586C"], (1953, 1961), "Subject and Special Files"),
                                        ("66 D 95", "2839192", ["A1 1586E"], (1947, 1979), "Records Relating to National Security Council Policy Papers"),
                                        ("62 D 1", "2838992", ["A1 1583E", "A1 1583F"], (1948, 1961), "Records Relating to Activities with the National Security Council")]:
    rows = lot(l)
    f = facts(naid)
    ok = bool(rows) and rows[0].get('naId') == naid and rows[0].get('hmsMlrEntryNumbers') == entries and f and (f.get('inclusiveStartYear'), f.get('inclusiveEndYear')) == years and f.get('accessStatus') == 'Restricted - Partly'
    rec(f"lot {l} -> NAID {naid}, entries {entries}, {years[0]}-{years[1]}, partly restricted, '{title}'", ok,
        f"central-files rows={len(rows)} {rows[0] if rows else ''}; facts={ {k: f.get(k) for k in ('creator','accessStatus','extent','inclusiveStartYear','inclusiveEndYear')} if f else None}")
rows = lot("61 D 385")
rec("lot 61 D 385 'not identified by the bundled data'", len(rows) == 0, f"central-files rows={len(rows)}")
# any other bundled file naming 61D385?
hits = []
import os
for fn in sorted(os.listdir(R)):
    if fn.endswith('.json'):
        t = open(R + fn).read()
        if re.search(r'61\s*-?D\s*-?385', t): hits.append(fn)
print("   files mentioning 61 D 385 in any spelling:", hits)
for fn in hits:
    t = open(R + fn).read()
    for m in re.finditer(r'.{120}61\s*-?D\s*-?385.{160}', t): print("     ", fn, "::", m.group(0).replace('\n', ' ')[:300]); break

print("\n== USIA series the overview names as nearest ==")
for naid, title, years, extent in [("40967285", "Subject Files of the Director", (1956, 1972), "103 linear feet"), ("1257679", "Subject Files (Office of Policy and Plans)", (1953, 1971), "47 linear feet"), ("40967113", "Chronological Files", (1961, 1966), None),
                                   ("1254251", "Program Files, Office of Research and Intelligence", (1954, 1958), None), ("7542975", "Records Relating to the Voice of America", (1948, 1959), None)]:
    f = facts(naid)
    lrows = [x for x in lots if x.get('naId') == naid]
    ok = f is not None and (f.get('inclusiveStartYear'), f.get('inclusiveEndYear')) == years and f.get('accessStatus') == 'Restricted - Partly' and (extent is None or f.get('extent', '').startswith(extent))
    rec(f"NAID {naid} '{title}' {years} {extent or ''} partly restricted", ok, f"facts={ {k: f.get(k) for k in ('creator','accessStatus','extent','inclusiveStartYear','inclusiveEndYear')} if f else None}; central-files lot rows with this naId: {[(x.get('recordGroup'), x.get('lotNumber'), x.get('title')) for x in lrows]}")

print("\n== record groups and repositories of the 31 (index document_sources) ==")
col = json.load(open("/Users/jbotts/frus-analysis/c3f/runs/f5/collection.fruscollection"))
docs = [(e['volumeId'], e['documentId']) for e in col['entries'] if e['kind'] == 'document']
rg306 = []
for v, d in docs:
    r = c.execute("SELECT repository, record_group, lot_file, series_name, citation_era, raw_text FROM document_sources WHERE volume_id=? AND document_id=?", [v, d]).fetchone()
    if r and r[1] == '306': rg306.append((v, d, r[5]))
print("RG 306 documents:", len(rg306))
ents = {"UD WW 257": 0, "UD WW 193": 0, "A1 42": 0, "P 104": 0, "P 207": 0}
accs = {"72 A 5121": 0, "68 A 4933": 0, "67 A 222": 0, "69 A 3445": 0}
for v, d, raw in rg306:
    sn = c.execute("SELECT source_note FROM document_cache WHERE volume_id=? AND document_id=?", [v, d]).fetchone()[0] or ''
    txt = raw + ' ' + sn
    for e in ents:
        if re.search(r'\b' + re.sub(r'\s+', r'[\\s–-]*', e) + r'\b', txt): ents[e] += 1
    for a in accs:
        if re.search(re.sub(r'\s+', r'[\\s–#-]*', a), txt): accs[a] += 1
    print(f"   {v}/{d}: {re.sub(chr(10),' ',sn)[:230]}")
rec("entries UD WW 257, UD WW 193, A1 42, P 104, P 207 appear in the eight RG 306 source notes", all(n >= 1 for n in ents.values()), str(ents))
rec("accessions 72 A 5121 and 68 A 4933 appear in the eight RG 306 source notes", accs["72 A 5121"] >= 1 and accs["68 A 4933"] >= 1, str(accs))
# entry numbers in any bundled JSON?
found = collections.defaultdict(list)
for fn in sorted(os.listdir(R)):
    if not fn.endswith('.json'): continue
    t = open(R + fn).read()
    for e in ents:
        pat = re.sub(r'\s+', r'[\\s–-]*', e)
        if re.search(r'(?<![\w])' + pat + r'(?![\w])', t): found[e].append(fn)
print("   entry numbers found in bundled JSON files:", dict(found))
# accession-series-index
ba = acc['byAccession']
for k in ["306/72A5121", "306/68A4933", "306/67A222", "306/69A3445"]:
    v = ba.get(k)
    print(f"   accession-series {k}: {len(v) if v else None} series", [(x.get('n'), x.get('t')) for x in (v or [])][:4])
rec("USIA 'Director's subject files' reached by accession 72 A 5121 / 68 A 4933 (overview wording)", ba.get("306/68A4933") is not None and any(x.get('t') == 'Subject Files of the Director' for x in ba["306/68A4933"]), "68A4933 names 'Subject Files of the Director' NAID 1102141 (15 series); 72A5121 names 18 series incl. 1257679 'Subject Files' (Policy and Plans)")

print("\n== other channels of the 31 ==")
tal = collections.Counter()
for v, d in docs:
    r = c.execute("SELECT repository, record_group, citation_era FROM document_sources WHERE volume_id=? AND document_id=?", [v, d]).fetchone()
    tal[(r[0], r[1], r[2])] += 1
for k, n in tal.most_common(): print("  ", n, k)
rec("five from the Johnson Library", tal[("Johnson Library", None, "structured")] == 5, "")
rec("two embassy files (RG 84 Saigon; RG 34 as printed)", tal[("National Archives", "84", "structured")] == 1 and tal[("National Archives", "34", "structured")] == 1, "")
rec("one Nixon Presidential Materials", tal[("Nixon Presidential Materials", None, "structured")] == 1, "")
rec("one printed as record group 305", tal[("National Archives", "305", "structured")] == 1, "")
rec("eight from RG 59 central files", sum(n for k, n in tal.items() if k[1] == '59' and k[2] in ('decimal', 'cfpf')) == 8, "")
rec("six RG 59 lot files", sum(n for k, n in tal.items() if k[1] == '59' and k[2] == 'lot_file') == 6, "")

print("\n== the d81 source note in full ==")
sn = c.execute("SELECT source_note, substr(body_text,1,300) FROM document_cache WHERE volume_id='frus1961-63v04' AND document_id='d81'").fetchone()
print(sn[0])
print("document_sources row:", c.execute("SELECT repository, record_group, lot_file, series_name, citation_era, raw_text FROM document_sources WHERE volume_id='frus1961-63v04' AND document_id='d81'").fetchone())

print("\n== M10: series before 1940 ==")
y0 = [r.get('y0') for r in by.values()]
cy0 = [r.get('cy0') for r in by.values()]
print("   byNaId rows:", len(by), "y0<1940:", sum(1 for y in y0 if y is not None and y < 1940), "min(y0,cy0)<1940:", sum(1 for r in by.values() if min([x for x in (r.get('y0'), r.get('cy0')) if x is not None] or [9999]) < 1940))

print("\n== pointed-at top units' identifiers (lots 66D95, 63D351 -> 2839192; 62D1 -> 2838992) ==")
print("   66D95:", lot("66 D 95")[0].get('naId') if lot("66 D 95") else None, "63D351:", lot("63 D 351")[0].get('naId') if lot("63 D 351") else None, "62D1:", lot("62 D 1")[0].get('naId') if lot("62 D 1") else None)

print("\nIDENTIFIERS CHECKED:", len(checked), "CONFIRMED:", sum(1 for _, ok, _ in checked if ok))
for n, ok, _ in checked:
    if not ok: print("   NOT CONFIRMED:", n)
