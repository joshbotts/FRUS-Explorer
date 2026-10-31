#!/usr/bin/env python3
"""Refuter archival-identifier check for cell f4: the bottom line's second paragraph against the bundled artifacts and the index."""
import json, re, sqlite3
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c = sqlite3.connect(DB, uri=True)

def load(n):
    try:
        return json.load(open(RES + n))
    except Exception as e:
        print("cannot load", n, e); return None
ca = load('collection-authority.json'); cf = load('central-files-index.json'); vs = load('volume-sources-index.json')
pl = load('presidential-library-catalog.json'); ec = load('external-citation-index.json'); sf = load('series-facts-index.json'); ai = load('accession-series-index.json')
for n, j in [('collection-authority', ca), ('central-files-index', cf), ('volume-sources-index', vs), ('presidential-library-catalog', pl), ('external-citation-index', ec), ('series-facts-index', sf), ('accession-series-index', ai)]:
    if j is not None:
        print(n, 'type', type(j).__name__, 'keys/len:', (list(j.keys())[:12] if isinstance(j, dict) else len(j)))

raw = {n: open(RES + n).read() for n in ['collection-authority.json', 'central-files-index.json', 'volume-sources-index.json', 'presidential-library-catalog.json', 'external-citation-index.json', 'series-facts-index.json', 'accession-series-index.json']}
def grep(s):
    hits = {n: len(re.findall(re.escape(s), t)) for n, t in raw.items()}
    return {k: v for k, v in hits.items() if v}
print('\n== grep of the bottom line\'s identifiers across the seven bundled files ==')
for s in ['72A5121', '72 A 5121', 'UD WW 257', 'UD WW 193', 'A1-42', 'A1–42', 'A1 42', 'P-104', 'P–104', 'P 104', 'P-207', 'P–207', 'P 207', '69A3445', '69 A 3445', '1257679', '2839192', '2839191', '2838992', '567979', '"1164"', '"1104"', '1586E', '1586C', '61 D 385', '61D385', '62 D 430', '62D430', '63 D 351', '63D351', '66 D 95', '66D95', '62 D 1"', '62D1"', '511.90', '790.5', '611.95', '611.98', 'D780405', 'Confidential File', 'Executive Secretariat Files', 'Brzezinski', 'Nixon Presidential Materials', 'Record Group 305', '"305"']:
    print(f"  {s!r}: {grep(s)}")

print('\n== series-facts-index: NAIDs 1257679, 2839192, 2839191, 2838992 ==')
if isinstance(sf, dict):
    print('legend:', json.dumps(sf.get('legend'))[:800])
    by = sf.get('byNaId') or sf.get('byNaid') or {}
    for naid in ['1257679', '2839192', '2839191', '2838992', '567979', '1164', '1104']:
        print(f"  {naid}: {json.dumps(by.get(naid), ensure_ascii=False)[:700]}")

print('\n== accession-series-index: 306/72A5121, 306/69A3445, 306/68A4933 ==')
if isinstance(ai, dict):
    print('top keys:', list(ai.keys())[:10])
    body = ai
    for k in ai:
        if isinstance(ai[k], dict) and any('/' in kk for kk in list(ai[k].keys())[:5]):
            body = ai[k]; print('accession map under key', k); break
    for key in ['306/72A5121', '306/69A3445', '306/68A4933']:
        v = body.get(key)
        print(f"  {key}: {'MISSING' if v is None else json.dumps(v, ensure_ascii=False)[:900]}")

print('\n== collection-authority: lots 61 D 385, 62 D 430, 63 D 351, 66 D 95, 62 D 1, 59 D 260 ==')
def walk(o, pred, path=''):
    if isinstance(o, dict):
        for k, v in o.items():
            yield from walk(v, pred, path + '/' + str(k))
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from walk(v, pred, path + f'[{i}]')
    else:
        if pred(o): yield path, o
cols = ca['collections'] if isinstance(ca, dict) and 'collections' in ca else ca
if isinstance(ca, dict): print('collection-authority keys:', list(ca.keys()))
def find_lot(lot):
    norm = lot.replace(' ', '').upper()
    out = []
    for col in (cols if isinstance(cols, list) else []):
        txt = json.dumps(col, ensure_ascii=False)
        if norm in txt.replace(' ', '').upper():
            out.append({k: col.get(k) for k in ('id', 'label', 'title', 'name', 'lotNumber', 'lot', 'naId', 'naid', 'nara', 'resolvedNaId', 'resolvedSeries', 'series', 'recordGroup', 'repository', 'dates', 'inclusiveDates') if k in col})
    return out
for lot in ['61 D 385', '62 D 430', '63 D 351', '66 D 95', '62 D 1', '59 D 260']:
    r = find_lot(lot)
    print(f"  {lot}: {len(r)} collections -> {json.dumps(r[:3], ensure_ascii=False)[:900]}")
if isinstance(cols, list) and cols:
    print('  sample collection keys:', list(cols[0].keys()))

print('\n== presidential-library-catalog: 567979, 1164, 1104, Confidential File, Nixon ==')
if pl is not None:
    txt = raw['presidential-library-catalog.json']
    for s in ['567979', '"1164"', '"1104"', 'Confidential File', 'Nixon']:
        for m in list(re.finditer(re.escape(s), txt))[:2]:
            print(f"  {s}: ...{txt[max(0, m.start()-200):m.end()+200].replace(chr(10), ' ')}...")

print('\n== document_sources rows for the 22 cited documents (the came-from paragraph) ==')
cited = [("frus1950v06","d50"),("frus1964-68v01","d122"),("frus1917-72PubDipv07","d85"),("frus1969-76v38p2","d105"),("frus1924v01","d540"),("frus1949v09","d558"),("frus1952-54v12p2","d403"),("frus1917-72PubDipv07","d32"),("frus1917-72PubDipv08","d58"),("frus1917-72PubDipv08","d99"),("frus1955-57v22","d447"),("frus1961-63v23","d289"),("frus1964-68v27","d386"),("frus1964-68v02","d160"),("frus1964-68v29p2","d46"),("frus1964-68v26","d106"),("frus1917-72PubDipv08","d31"),("frus1955-57v23p2","d50"),("frus1977-80v30","d79"),("frus1917-72PubDipv08","d146"),("frus1917-72PubDipv08","d149"),("frus1977-80v30","d152")]
from collections import Counter
rg = Counter()
for v, d in cited:
    r = c.execute("SELECT repository, record_group, lot_file, series_name, citation_era, decimal_class, substr(replace(raw_text,char(10),' '),1,260) FROM document_sources WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    print(f"  {v}/{d}: {r}")
    if r: rg[(r[0], r[1])] += 1
    else: rg[('NO ROW', None)] += 1
print('  tally by (repository, record_group):', dict(rg))

print('\n== external_citations over S2 for the pointed-at paragraph (re-run of arch1.py\'s third query) ==')
S = json.load(open('/Users/jbotts/frus-analysis/c3f/runs/f4/scope_sets.json'))
c.execute("CREATE TEMP TABLE R(volume_id TEXT PRIMARY KEY)"); c.executemany("INSERT INTO R VALUES (?)", [(v,) for v in S['R']])
U = '''(USIS OR USIA OR JUSPAO OR "Information Agency" OR "Information Service" OR "psychological warfare" OR "psychological operations" OR "psychological strategy" OR "information program" OR "cultural exchange" OR "educational exchange" OR Fulbright OR "Voice of America" OR "exchange of persons" OR "hearts and minds" OR "cultural program" OR "Asia Foundation" OR "leader grant" OR "information officer" OR "cultural affairs" OR "cultural relations" OR "public diplomacy" OR "information activities")'''
c.execute("CREATE TEMP TABLE S2 AS SELECT d.volume_id v, d.document_id i FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ?", (U,))
for r in c.execute("SELECT e.repository, e.collection, e.lot_file_norm, COUNT(*) n, COUNT(DISTINCT e.volume_id||'/'||e.document_id) docs FROM external_citations e JOIN S2 x ON x.v=e.volume_id AND x.i=e.document_id GROUP BY 1,2,3 ORDER BY n DESC LIMIT 12"):
    print('  ', r)
print('\n== document_sources over S2: top lots (re-run) ==')
for r in c.execute("SELECT s.lot_file, s.record_group, COUNT(*) n FROM document_sources s JOIN S2 x ON x.v=s.volume_id AND x.i=s.document_id WHERE s.lot_file IS NOT NULL GROUP BY 1,2 ORDER BY n DESC LIMIT 6"):
    print('  ', r)
