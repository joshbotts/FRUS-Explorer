# Refuter re-runs for cell f9: coverage, scope denominators, headline numbers, gap queries, strict reach.
import sqlite3, sys, json, re, collections
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f9/"
c = sqlite3.connect(DB, uri=True)

R = open(RUN + "R_in.txt").read().strip()
RI = open(RUN + "RI_in.txt").read().strip()
Rl = [x.strip("'") for x in R.split(",")]
RIl = [x.strip("'") for x in RI.split(",")]
Il = [v for v in RIl if v not in Rl]
print("R volumes", len(Rl), "I volumes", len(Il), "R+I", len(RIl), "distinct", len(set(RIl)))
print("I =", Il)

print("\n[M1] coverage:", c.execute("SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache").fetchone())

NA = "d.is_front_matter=0 AND d.is_editorial_note=0"
def cnt(where, params=()):
    return c.execute(f"SELECT COUNT(*) FROM document_cache d WHERE {where}", params).fetchone()[0]
print("[M3] R non-apparatus:", cnt(f"{NA} AND d.volume_id IN ({R})"))
print("[M3] I non-apparatus:", cnt(f"{NA} AND d.volume_id IN ({','.join(repr(v) for v in Il)})"))
print("[M3] R+I non-apparatus:", cnt(f"{NA} AND d.volume_id IN ({RI})"))
# date span of R+I dated documents
print("[M3] date span R+I:", c.execute(f"SELECT MIN(dd.date_iso), MAX(dd.date_iso) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE {NA} AND d.volume_id IN ({RI})").fetchone())
print("[M3] decade dist R+I:", c.execute(f"SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE {NA} AND d.volume_id IN ({RI}) GROUP BY 1 ORDER BY 1").fetchall())
print("Ed2 volumes in scope:", [v for v in RIl if "Ed2" in v])

J = "FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid"
def mcount(match, vols):
    return c.execute(f"SELECT COUNT(*), COUNT(DISTINCT d.volume_id) {J} WHERE frus_documents MATCH ? AND {NA} AND d.volume_id IN ({vols})", (match,)).fetchone()

UNION = 'usia OR usi OR "information program" OR "psychological warfare" OR "Voice of America" OR "public diplomacy" OR "cultural exchange"'
Istr = ",".join(repr(v) for v in Il)
print("\n[M5] union family R:", mcount(UNION, R), "I:", mcount(UNION, Istr), "R+I:", mcount(UNION, RI))
for name, m in [("POS Department of State", '"Department of State"'), ("NEG", "ZZZ_IMPOSSIBLE_ZZZ"), ("soft power", '"soft power"'),
                ("propaganda", "propaganda"), ("psycholog", "psycholog"), ("usia OR usi", "usia OR usi"), ("information program", '"information program"'),
                ("image of the United States", '"image of the United States"'), ("prestig", "prestig"), ("public diplomacy", '"public diplomacy"'),
                ("cultural exchange", '"cultural exchange"'), ("Voice of America", '"Voice of America"'), ("psychological warfare", '"psychological warfare"'),
                ("hearts and minds", '"hearts and minds"'),
                ("asian mind family", '"Asian mind" OR "Oriental mind" OR "Asian mentality" OR "Oriental mentality" OR "Asian psychology" OR "Oriental psychology"')]:
    print(f"  {name}: R {mcount(m, R)} I {mcount(m, Istr)}")
# positive control lowest volume
rows = c.execute(f"SELECT d.volume_id, COUNT(*) n {J} WHERE frus_documents MATCH '\"Department of State\"' AND {NA} AND d.volume_id IN ({RI}) GROUP BY 1 ORDER BY n LIMIT 3", ).fetchall()
print("  POS lowest volumes:", rows, "volumes with POS>0:", c.execute(f"SELECT COUNT(DISTINCT d.volume_id) {J} WHERE frus_documents MATCH '\"Department of State\"' AND {NA} AND d.volume_id IN ({RI})").fetchone())

print("\n[M9] gap queries over R+I:")
GAPS = {'POS': '"Department of State"', 'NEG': 'ZZZ_IMPOSSIBLE_ZZZ', 'soft power': '"soft power"', 'soft': 'soft',
        'poll/survey+usia': '(poll OR survey) AND (usia OR usi)', '+japan': '(poll OR survey) AND (usia OR usi) AND (japan OR japanes)',
        'usia+aus/nz': '(usia OR usi) AND (australia OR "new zealand")', 'usia+pacific': '(usia OR usi) AND (micronesia OR fiji OR "trust territory" OR samoa OR guam)',
        'fulbright': 'fulbright', 'fulbright+eval': 'fulbright AND (evaluat OR effect OR impact)',
        'asian mind': '"Asian mind" OR "Oriental mind" OR "Asian mentality" OR "Oriental mentality" OR "Asian psychology" OR "Oriental psychology"',
        'face': '"lose face" OR "loss of face" OR "save face" OR "saving face" OR "face saving"'}
for k, m in GAPS.items():
    print(f"  {k}: {mcount(m, RI)}")

print("\n[M4] header queries:")
HI = 'header:(japan OR japanes OR china OR chines OR korea OR vietnam OR vietnames OR asia OR asian OR indonesia OR philippin OR thailand OR lao OR laos OR burma OR "far east" OR pacif OR southeast OR taiwan OR cambodia)'
HR = 'header:(usia OR usi OR "information agency" OR "information service" OR psycholog OR propaganda OR "public affairs" OR "information program" OR "operations coordinating board" OR "psychological strategy board" OR cultur OR "public opinion")'
hi = c.execute(f"SELECT d.volume_id, d.document_id {J} WHERE frus_documents MATCH ? AND {NA} AND d.volume_id IN ({Istr})", (HI,)).fetchall()
hr = c.execute(f"SELECT d.volume_id, d.document_id {J} WHERE frus_documents MATCH ? AND {NA} AND d.volume_id IN ({R})", (HR,)).fetchall()
cand = set(hi) | set(hr)
print("  I-header hits:", len(hi), "R-header hits:", len(hr), "union:", len(cand), "overlap:", len(set(hi) & set(hr)))
file_cand = set(tuple(l.strip().split("|")) for l in open(RUN + "candidate_set.txt") if l.strip())
print("  candidate_set.txt:", len(file_cand), "equal to re-run:", file_cand == cand)

print("\n[M11] came-from of the 141 by record group:")
rg = collections.Counter(); era = collections.Counter(); norow = 0
for v, d in sorted(cand):
    r = c.execute("SELECT repository, record_group, citation_era FROM document_sources WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if not r: norow += 1; continue
    rg[(r[0], r[1])] += 1; era[r[2]] += 1
print("  without row:", norow)
for k, n in rg.most_common(): print("  ", n, k)
rg59 = sum(n for (rep, g), n in rg.items() if g == '59'); rg306 = sum(n for (rep, g), n in rg.items() if g == '306')
print(f"  RG 59 total {rg59} ({rg59/141:.3f}), RG 306 total {rg306} ({rg306/141:.3f})")
print("  citation_era:", era.most_common())

print("\n[M8] ranked predicate count over R+I:")
M8 = '(usia OR usi OR propaganda OR psycholog OR "information program") AND (asian OR asia OR "far east" OR "far eastern") AND (attitud OR opinion OR imag OR prestig) AND (effect OR effective OR impact OR assess)'
print("  ", mcount(M8, RI))
m8set = set(c.execute(f"SELECT d.volume_id, d.document_id {J} WHERE frus_documents MATCH ? AND {NA} AND d.volume_id IN ({RI})", (M8,)).fetchall())

print("\n[REACH] the 25 collection pairs against every logged MATCH predicate (over its logged volume scope):")
pairs = [tuple(l.split()) for l in open(RUN + "collection_pairs.txt") if l.strip()]
fam = json.load(open(RUN + "scan_families.json"))
famq = fam if isinstance(fam, dict) else {}
print("  scan_families.json type:", type(fam).__name__, "keys/len:", (list(fam.keys()) if isinstance(fam, dict) else len(fam)))
preds = {}  # name -> (match, volscope)
if isinstance(fam, dict):
    for k, v in fam.items():
        m = v if isinstance(v, str) else (v.get('match') or v.get('q') or v.get('query'))
        if m: preds[f"fam:{k}"] = (m, RI)
for k, m in GAPS.items(): preds[f"gap:{k}"] = (m, RI)
preds["M8 ranked"] = (M8, RI)
preds["hdr I"] = (HI, Istr); preds["hdr R"] = (HR, R)
preds["decades union (R minus 2)"] = (UNION, ",".join(repr(v) for v in Rl if v not in ('frus1948v06', 'frus1949v07p1')))
# evaluate per pair
asian_census = set(c.execute(f"SELECT d.volume_id, d.document_id {J} WHERE frus_documents MATCH ? AND {NA} AND d.volume_id IN ({RI})", (GAPS['asian mind'],)).fetchall())
top45 = set()
for l in open(RUN + "ranked1.txt"):
    p = l.split("|");
    if len(p) > 2: top45.add((p[0], p[1]))
for v, d in pairs:
    hits = []
    for name, (m, vols) in preds.items():
        n = c.execute(f"SELECT COUNT(*) {J} WHERE frus_documents MATCH ? AND {NA} AND d.volume_id IN ({vols}) AND d.volume_id=? AND d.document_id=?", (m, v, d)).fetchone()[0]
        if n: hits.append(name)
    printed = []
    if (v, d) in file_cand: printed.append("candidate_set(141, printed)")
    if (v, d) in top45: printed.append("ranked top45 (printed)")
    if (v, d) in asian_census: printed.append("asian-mind census (printed in gaps.txt)")
    print(f"  {v}/{d}: predicates matched = {len(hits)} {hits[:6]}{'...' if len(hits)>6 else ''} | printed result sets: {printed}")

print("\n[d116 / d104] M8 predicate without scope restriction (as logged at line 33):")
print("  ", c.execute(f"SELECT COUNT(*) {J} WHERE frus_documents MATCH ? AND d.volume_id||'/'||d.document_id IN ('frus1952-54v13p1/d116','frus1977-80v22/d104')", (M8,)).fetchone())
for name, (m, vols) in preds.items():
    n = c.execute(f"SELECT COUNT(*) {J} WHERE frus_documents MATCH ? AND {NA} AND d.volume_id IN ({vols}) AND d.volume_id='frus1952-54v13p1' AND d.document_id='d116'", (m,)).fetchone()[0]
    if n: print("  d116 matched by:", name, "|", m[:90])

print("\n[M14] collection pairs present, non-apparatus, dates:")
for v, d in pairs:
    r = c.execute("SELECT is_front_matter, is_editorial_note, length(body_text), (SELECT date_iso FROM document_dates WHERE volume_id=d.volume_id AND document_id=d.document_id), substr(replace(header,char(10),' '),1,90) FROM document_cache d WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    print(f"  {v}/{d}: {r}")

print("\n[house figure] earliest dated external_citations row:")
print("  ", c.execute("SELECT MIN(dd.date_iso) FROM external_citations e JOIN document_dates dd ON dd.volume_id=e.volume_id AND dd.document_id=e.document_id").fetchone())
print("  rows with date < 1910-12-06:", c.execute("SELECT COUNT(*) FROM external_citations e JOIN document_dates dd ON dd.volume_id=e.volume_id AND dd.document_id=e.document_id WHERE dd.date_iso < '1910-12-06'").fetchone())

print("\n[M12] pointed-at rows for the 141 by lot:")
pa = collections.Counter(); pad = collections.defaultdict(set)
for v, d in sorted(cand):
    for row in c.execute("SELECT repository, collection, lot_file_norm FROM external_citations WHERE volume_id=? AND document_id=?", (v, d)):
        pa[row] += 1; pad[row].add((v, d))
for k, n in pa.most_common(20): print("  ", n, len(pad[k]), k, sorted(pad[k])[:4] if k[2] in ('65D101', '66D95', '63D351', '71D273', '60D627') else "")
print("\n[M16] pointed-at rows for the 25 collection docs:")
for v, d in pairs:
    rows = c.execute("SELECT repository, collection, lot_file_norm, anchor, substr(raw_text,1,160) FROM external_citations WHERE volume_id=? AND document_id=?", (v, d)).fetchall()
    if rows:
        print(f"  {v}/{d}: {len(rows)} rows")
        for r in rows: print("     ", r)
