# Refuter f3: archival identifiers against the bundled JSONs, and reach of each cited document through the logged queries.
import sqlite3, re, json, collections
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f3"
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
con = sqlite3.connect(DB, uri=True)
vols = [l.strip() for l in open(RUN + "/scope_volumes.txt") if l.strip()]
def ql(vs): return ",".join("'%s'" % v for v in vs)
APP = "c.is_front_matter=0 AND c.is_editorial_note=0"

print("== 4. ARCHIVAL IDENTIFIERS ==")
cf = json.load(open(RES + "/central-files-index.json")); sf = json.load(open(RES + "/series-facts-index.json"))
vs = json.load(open(RES + "/volume-sources-index.json")); acc = json.load(open(RES + "/accession-series-index.json"))
L = sf['legend']['keys']
def facts(na):
    row = sf['byNaId'].get(str(na))
    if not row: return None
    out = {}
    for k, v in row.items():
        spec = L.get(k, {}); f = spec.get('field', k)
        if 'into' in spec:
            arr = sf[spec['into']]; out[f] = [arr[i] for i in v] if isinstance(v, list) else arr[v]
        else: out[f] = v
    return out
by = collections.defaultdict(list)
for r in cf['lotFiles']: by[r['lotNumber']].append(r)
for lot in ['63D351', '66D95', '62D430', '62D1', '59D260', '70D398']:
    for r in by.get(lot, []):
        f = facts(r.get('naId')) or {}
        print("  lot %s -> RG %s | entry %s | NAID %s | %s | %s–%s | %s | %s | %s" % (lot, r.get('recordGroup'), r.get('hmsMlrEntryNumbers'), r.get('naId'), r.get('title'), f.get('inclusiveStartYear'), f.get('inclusiveEndYear'), f.get('accessStatus'), f.get('accessRestrictions'), f.get('referenceUnit')))
        if lot == '59D260': print("     extent:", f.get('extent'), "| creator:", f.get('creator'))
    if lot not in by: print("  lot %s NOT IN central-files-index" % lot)
print("  RG 306 in volume-sources-index recordGroups:", vs.get('recordGroups', {}).get('306'))
# NAID 622 anywhere in series-facts?
print("  series-facts byNaId has 622:", '622' in sf['byNaId'])
for key in ['306/72A5121', '306/69A3445', '306/67A222', '306/68A4933']:
    rows = acc['byAccession'].get(key)
    print("  accession %s -> %s series" % (key, len(rows) if rows else None), [x['t'] for x in rows][:4] if rows else None)
# Are 63D351 / 66D95 / 62D430 / 62D1 really pointed-at by C docs, and 59D260 by frus1955-57v09/d207?
C = [tuple(l.split('\t')) for l in open(RUN + "/raw/coreset_clean.tsv").read().split('\n') if l]
Cset = set(C)
for lot in ['63D351', '66D95', '62D430', '62D1', '59D260', '70D398']:
    rows = con.execute("SELECT volume_id, document_id FROM external_citations WHERE lot_file_norm=?", (lot,)).fetchall()
    inC = set(rows) & Cset
    rows2 = con.execute("SELECT volume_id, document_id FROM document_sources WHERE lot_file_norm=?", (lot,)).fetchall()
    inC2 = set(rows2) & Cset
    print("  lot %s: pointed-at by %d C docs (corpus %d distinct docs); came-from %d C docs (corpus %d)" % (lot, len(inC), len(set(rows)), len(inC2), len(set(rows2))))
r = con.execute("SELECT lot_file_norm, raw_text FROM external_citations WHERE volume_id='frus1955-57v09' AND document_id='d207'").fetchall()
print("  frus1955-57v09/d207 external_citations lots:", [x[0] for x in r])
print("  ... raw_text of the 59D260 row:", [x[1][:160] for x in r if x[0] == '59D260'])
# Director's subject files and East Asia area office files among RG 306 came-from rows of C
rg306 = collections.Counter()
for v, d in C:
    r = con.execute("SELECT series_name FROM document_sources WHERE volume_id=? AND document_id=? AND record_group='306'", (v, d)).fetchone()
    if r: rg306[r[0]] += 1
print("  RG 306 came-from series names over C:", rg306.most_common(12))
# RG 305 misprint check
r = con.execute("SELECT repository, record_group, series_name, raw_text FROM document_sources WHERE volume_id='frus1969-76v38p2' AND document_id='d105'").fetchone()
print("  frus1969-76v38p2/d105 document_sources:", r)
# 70D398 named in volume-sources-index for which scope volumes?
hits = []
for vid, row in vs.get('volumes', vs.get('byVolume', {})).items() if isinstance(vs.get('volumes', vs.get('byVolume')), dict) else []:
    s = json.dumps(row)
    if '70 D 398' in s or '70D398' in s: hits.append(vid)
print("  volume-sources-index volumes naming lot 70 D 398:", hits, "| in scope:", [h for h in hits if h in vols])
print("  volume-sources-index top-level keys:", list(vs.keys()))

print("\n== 7. REACH ==")
cited = [tuple(l.split('/')) for l in open(RUN + "/raw/collection_ids.txt").read().split()]
core_raw = set(tuple(l.split('\t')) for l in open(RUN + "/raw/coreset.tsv").read().split('\n') if l)
rank = set(tuple(l.split('|')[0].split('/')) for l in open(RUN + "/raw/rank_q1.txt").read().split('\n') if l)
aud = set(tuple(l.split('/')) for l in open(RUN + "/raw/audience_ids.txt").read().split())
# re-run the logged Japan query (queries.log line 24), LIMIT 20
JV = ['frus1952-54v14p2','frus1955-57v23p1','frus1958-60v18','frus1961-63v22','frus1964-68v29p2','frus1969-76v19p2','frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1961-63v25','frus1955-57v09']
jq = "SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '(usia OR usi OR \"information program\" OR \"cultural exchange\" OR \"exchange program\") AND (japan OR japanese) AND (intellectu* OR neutralis* OR attitud* OR imag*)' AND %s AND c.volume_id IN (%s) ORDER BY bm25(frus_documents) LIMIT 20" % (APP, ql(JV))
japan = con.execute(jq).fetchall(); japan_set = set(japan)
print("Japan query (log line 24) returns", len(japan), "rows:", ['%s/%s' % p for p in japan])
# re-run the logged rank query (line 20), LIMIT 70, compare with raw/rank_q1.txt
rq = "SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '(usia OR usi OR \"information program\" OR \"psychological\" OR propaganda) AND (\"east asia\" OR \"far east\" OR \"southeast asia\" OR asian) AND (effect* OR attitud* OR audienc* OR imag* OR opinion)' AND %s AND c.volume_id IN (%s) ORDER BY bm25(frus_documents) LIMIT 70" % (APP, ql(vols))
rank2 = set(con.execute(rq).fetchall())
print("rank query (log line 20) re-run == raw/rank_q1.txt:", rank2 == rank, len(rank2), len(rank))
# the audience query (line 22) re-run
aq = "SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '\"asian mind\" OR \"oriental mind\" OR \"asians respect\" OR \"lose face\" OR \"asian psychology\"' AND %s AND c.volume_id IN (%s)" % (APP, ql(vols))
aud2 = set(con.execute(aq).fetchall())
print("audience query (log line 22) re-run == raw/audience_ids.txt:", aud2 == aud, len(aud2), len(aud))
circ = set(con.execute("SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '\"circular telegram 208\" OR (depcirtel AND 208 AND inform*)' AND %s" % APP).fetchall())
print("circular query (log line 48) returns:", sorted(circ))
# per-volume scope-rank query (line 11) returns volumes only, not documents: not a document query.
print("\nper cited document: C(clean) | C(raw 1,573) | rank70 | audience92 | japan20 | circular | ANY-FULLTEXT")
anyn = 0; strict_vec = []; untraced = []
for v, d in cited:
    p = (v, d)
    flags = [p in Cset, p in core_raw, p in rank, p in aud, p in japan_set, p in circ]
    anyf = any(flags); anyn += anyf
    print("  %-28s %s %s" % (v + '/' + d, ' '.join('Y' if f else '.' for f in flags), 'FULLTEXT' if anyf else 'NONE'))
    if not anyf: untraced.append(p)
print("cited:", len(cited), "returned by >=1 logged full-text query:", anyn, "| none:", untraced)
print("d116 in raw coreset.tsv (saved at log line 26, before vectors.py at line 40):", ('frus1952-54v13p1', 'd116') in core_raw, "| in clean C (line 28):", ('frus1952-54v13p1', 'd116') in Cset, "| in rank70 (line 20):", ('frus1952-54v13p1', 'd116') in rank, "| in audience92:", ('frus1952-54v13p1', 'd116') in aud)
# which logged query first returned each of the audience-only docs (line order): rank20 < audience22 < japan24 < coreset26
print("\nlog order of first full-text surfacing:")
for v, d in cited:
    p = (v, d); first = None
    for name, s in [('line20 rank70', rank), ('line22 audience92', aud), ('line24 japan20', japan_set), ('line26 coreset', core_raw)]:
        if p in s: first = name; break
    print("  %-28s %s" % (v + '/' + d, first))
