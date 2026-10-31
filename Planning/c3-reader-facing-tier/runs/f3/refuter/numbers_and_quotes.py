# Refuter f3: headline numbers, zeros, scope span, quotation check, edition-citation resolution.
import sqlite3, re, json, collections
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f3"
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
con = sqlite3.connect(DB, uri=True)
vols = [l.strip() for l in open(RUN + "/scope_volumes.txt") if l.strip()]
GLOBAL = ['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1955-57v09','frus1961-63v25','frus1969-76v38p2','frus1977-80v30','frus1952-54v02p2','frus1950-55Intel']
REG = [v for v in vols if v not in GLOBAL]
def ql(vs): return ",".join("'%s'" % v for v in vs)
APP = "c.is_front_matter=0 AND c.is_editorial_note=0"

print("== 1. SCOPE ==")
print("scope list length:", len(vols), "distinct:", len(set(vols)), "regional:", len(REG), "global:", len(GLOBAL))
r = con.execute("SELECT COUNT(DISTINCT volume_id), COUNT(*) FROM document_cache c WHERE %s AND volume_id IN (%s)" % (APP, ql(vols))).fetchone()
print("[M2] scope volumes, non-apparatus docs:", r)
r = con.execute("SELECT COUNT(DISTINCT volume_id), COUNT(*) FROM document_cache c WHERE %s AND volume_id IN (%s)" % (APP, ql(REG))).fetchone()
print("[M2b] regional volumes, non-apparatus docs:", r)
r = con.execute("SELECT MIN(d.date_iso), MAX(d.date_iso), COUNT(*), SUM(d.date_iso IS NULL) FROM document_cache c LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE %s AND c.volume_id IN (%s)" % (APP, ql(vols))).fetchone()
print("scope document date span (date_iso min, max, n, undated):", r)
r = con.execute("SELECT MIN(d.date_iso), MAX(d.date_iso) FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE %s AND c.volume_id IN (%s)" % (APP, ql(REG))).fetchone()
print("regional-volume date span:", r)
rows = con.execute("SELECT substr(d.date_iso,1,4) y, COUNT(*) FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE %s AND c.volume_id IN (%s) AND (d.date_iso < '1946' OR d.date_iso >= '1981') GROUP BY y ORDER BY y" % (APP, ql(vols))).fetchall()
print("scope docs dated before 1946 or after 1980, by year:", rows)
m = json.load(open(RES + "/manifest.json"))
mv = {x['volumeId']: x for x in m}
missing = [v for v in vols if v not in mv]
print("scope volumes missing from manifest:", missing)
e = min(mv[v]['dateRange']['earliest'] for v in vols if v in mv); l = max(mv[v]['dateRange']['latest'] for v in vols if v in mv)
print("manifest dateRange over scope: earliest", e, "latest", l)
r = con.execute("SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache").fetchone()
print("[M0] index coverage:", r)
r = con.execute("SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0").fetchone()
print("[M0b] non-apparatus corpus-wide:", r)

print("\n== 2. HEADLINE NUMBERS ==")
# (1) soft power
for label, where in [("corpus-wide, all docs", ""), ("corpus-wide, non-apparatus", " AND " + APP), ("scope, non-apparatus", " AND %s AND c.volume_id IN (%s)" % (APP, ql(vols)))]:
    r = con.execute("SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '\"soft power\"'" + where).fetchone()
    print("[M1] \"soft power\" %s:" % label, r)
r = con.execute("SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'soft' AND %s AND c.volume_id IN (%s)" % (APP, ql(vols))).fetchone()
print("[M1b] relaxed 'soft' in scope:", r)
r = con.execute("SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'soft AND power' AND %s AND c.volume_id IN (%s)" % (APP, ql(vols))).fetchone()
print("     'soft AND power' (both words, any distance) in scope:", r)
# (2) core set C
FAM = '(usia OR usi OR "information program" OR "psychological strategy" OR "psychological warfare" OR "cultural exchange")'
ASIA = '(asia OR asian OR "far east" OR japan OR japanese OR korea OR vietnam OR "viet nam" OR philippines OR indonesia OR thailand OR laos OR cambodia OR burma OR china OR chinese OR taiwan OR australia OR pacific)'
q = "SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND %s AND c.volume_id IN (%%s)" % APP
a = con.execute(q % ql(REG), (FAM,)).fetchall(); b = con.execute(q % ql(GLOBAL), (FAM + ' AND ' + ASIA,)).fetchall()
core = sorted(set(a + b))
print("[M3] regional", len(a), "global", len(b), "union", len(core), "volumes", len(set(v for v, d in core)))
T = re.compile(r'\b(USIAs?|USIS|USIE|information[\s\-,().]+programs?|psychological[\s\-,().]+(strateg\w*|warfare)|cultural[\s\-,().]+exchanges?|U\.\s?S\.\s?I\.\s?[AS]\.?|Information Agency|Information Service)', re.I)
USI = re.compile(r'\bUSI\b')
keep = []; drop = collections.Counter(); usi = 0
for v, d in core:
    x = re.sub(r'\s+', ' ', ' '.join(con.execute("SELECT header,coalesce(dateline,''),coalesce(source_note,''),body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()))
    if T.search(x): keep.append((v, d))
    else:
        drop[v] += 1
        if USI.search(x): usi += 1
print("[M5] kept", len(keep), "dropped", len(core) - len(keep), "bare-USI among dropped", usi, "kept volumes", len(set(v for v, d in keep)), "top dropped", drop.most_common(3))
sess = set(tuple(l.split('\t')) for l in open(RUN + "/raw/coreset_clean.tsv").read().split('\n') if l)
print("     my C == session's raw/coreset_clean.tsv:", set(keep) == sess, "(mine %d, session %d)" % (len(keep), len(sess)))
C = keep
# (3) 23 documents cited in overview
ov = open(RUN + "/overview.md").read()
urls = re.findall(r'https://history\.state\.gov/historicaldocuments/(frus[^/\s)]+)/(d\d+)', ov)
cited = []
for u in urls:
    if u not in cited: cited.append(u)
print("overview URLs:", len(urls), "distinct pairs:", len(cited))
# (4)/(5) came-from shares over C
cf = collections.Counter(); era = collections.Counter(); nsrc = 0; npa = 0; cfseries = collections.Counter()
for v, d in C:
    r = con.execute("SELECT repository, record_group, lot_file_norm, series_name, citation_era FROM document_sources WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if r: nsrc += 1; cf[(r[0], r[1])] += 1; era[r[4]] += 1; cfseries[(r[0], r[1], r[2], r[3])] += 1
    n = con.execute("SELECT COUNT(*) FROM external_citations WHERE volume_id=? AND document_id=?", (v, d)).fetchone()[0]
    if n: npa += 1
rg59 = cf[('Department of State', '59')] + cf[('National Archives', '59')]
rg306 = cf[('National Archives', '306')]
print("[M11] came-from rows:", nsrc, "of", len(C), "| RG 59 =", cf[('Department of State', '59')], "+", cf[('National Archives', '59')], "=", rg59, "-> %.1f%%" % (100.0 * rg59 / len(C)), "| RG 306 =", rg306, "-> %.1f%% = 1 in %.1f" % (100.0 * rg306 / len(C), len(C) / rg306))
print("     any-RG59 record_group (all repositories):", sum(c for (rep, rg), c in cf.items() if rg == '59'))
print("     top repository/RG:", cf.most_common(12))
libs = sum(c for (rep, rg), c in cf.items() if rep and 'Library' in rep or (rep or '').startswith('Nixon'))
rest = len(C) - rg59 - rg306
print("     presidential libraries + Nixon Materials:", libs, "of the remaining", rest, "(%.0f%%)" % (100.0 * libs / rest))
nsf = sum(c for k, c in cfseries.items() if k[3] and ('National Security' in k[3] or k[3] == 'NSC Files'))
print("     series named National Security File(s)/NSC Files/National Security Affairs/Adviser:", nsf, "of the remaining", rest)
print("[M12] pointed-at: docs with >=1 external_citations row:", npa, "of", len(C), "-> %.1f%% = 1 in %.1f" % (100.0 * npa / len(C), len(C) / npa))
print("     citation_era split:", era.most_common())
# controls
for term in ['"department of state"', 'ZZZ_IMPOSSIBLE_ZZZ', '"oriental mind"', '"asian mind"']:
    r1 = con.execute("SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND %s AND c.volume_id IN (%s)" % (APP, ql(vols)), (term,)).fetchone()
    r2 = con.execute("SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND %s" % APP, (term,)).fetchone()
    print("[M7/M8/M9] %-22s scope: %s  corpus-wide: %s" % (term, r1, r2))
print("     scope share of non-apparatus corpus: 35214/312169 = 1 in %.2f" % (312169 / 35214.0))
# density per decade (clean C, regional part)
den = dict(con.execute("SELECT substr(d.date_iso,1,3)||'0s', COUNT(*) FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE %s AND d.date_iso IS NOT NULL AND c.volume_id IN (%s) GROUP BY 1" % (APP, ql(REG))).fetchall())
num = collections.Counter()
for v, d in C:
    if v in GLOBAL: continue
    r = con.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if r and r[0]: num[r[0][:3] + '0s'] += 1
for dec in sorted(den): print("[M10] %s C(regional) %d / dated %d = %.1f per 1,000 = 1 in %.0f" % (dec, num[dec], den[dec], 1000.0 * num[dec] / den[dec], den[dec] / float(num[dec]) if num[dec] else 0))
# circular 208
for t in ['"circular telegram 208"', '"circular telegram" AND 208']:
    r = con.execute("SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND %s" % APP, (t,)).fetchone()
    print("[§8] %s corpus-wide non-apparatus:" % t, r)
# the 1910-12-06 house-rule figure
r = con.execute("SELECT MIN(d.date_iso) FROM external_citations e JOIN document_dates d ON d.volume_id=e.volume_id AND d.document_id=e.document_id").fetchone()
print("[house rule] earliest dated document with an external_citations row:", r)
# unqueried absence claims
for t in ['"country plan"', '"country plans"', '"opinion survey" OR "opinion surveys" OR "public opinion survey"', '"office of research"']:
    r = con.execute("SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND %s AND c.volume_id IN (%s)" % (APP, ql(vols)), (t,)).fetchone()
    print("[absence claim probe] %-70s scope:" % t, r)

print("\n== 3. QUOTATIONS ==")
def norm(s): return re.sub(r'[^a-z0-9]', '', s.lower())
def segments(q):
    parts = re.split(r'\[\.\.\.\]|\.\.\.|…', q)
    return [norm(p) for p in parts if norm(p)]
texts = {}
def doc_text(v, d):
    if (v, d) not in texts:
        r = con.execute("SELECT header, coalesce(dateline,''), coalesce(source_note,''), body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
        texts[(v, d)] = (norm(r[0] + r[1] + r[2] + r[3]), r[4], r[5]) if r else None
    return texts[(v, d)]
def check(q, v, d):
    t = doc_text(v, d)
    if t is None: return ("NO SUCH ROW", [])
    segs = segments(q); pos = 0; offs = []
    for s in segs:
        i = t[0].find(s, pos)
        if i < 0: return ("NOT FOUND segment %d of %d" % (len(offs) + 1, len(segs)), offs)
        offs.append(i); pos = i + len(s)
    return ("FOUND", offs)
coll = json.load(open(RUN + "/collection.fruscollection"))
ex = [e for e in coll['entries'] if e['kind'] == 'excerpt']
print("collection excerpts:", len(ex))
nf = 0
for i, e in enumerate(ex, 1):
    res, offs = check(e['text'], e['volumeId'], e['documentId'])
    nf += res == "FOUND"
    print("  EX%02d %s/%s %s %s | %s" % (i, e['volumeId'], e['documentId'], res, offs, e['text'][:70]))
print("excerpts FOUND:", nf, "of", len(ex))
# overview spans
spans = [(mo.start(), mo.end(), mo.group(1)) for mo in re.finditer(r'"([^"]+)"', ov)]
urlpos = [(mo.start(), mo.group(1), mo.group(2)) for mo in re.finditer(r'https://history\.state\.gov/historicaldocuments/(frus[^/\s)]+)/(d\d+)', ov)]
def next_url(pos):
    for p, v, d in urlpos:
        if p > pos: return (v, d)
    return None
print("\noverview double-quoted spans:", len(spans))
for n, (s, e, q) in enumerate(spans, 1):
    line = ov.count('\n', 0, s) + 1
    pair = next_url(e)
    if pair:
        res, offs = check(q, *pair)
    else:
        res, offs = ("(no following URL)", [])
    print("  S%02d line %d -> %s | %s | %s | %s" % (n, line, pair, res, offs, q[:80]))
json.dump([dict(n=n, line=ov.count('\n', 0, s) + 1, text=q, pair=next_url(e)) for n, (s, e, q) in enumerate(spans, 1)], open(RUN + "/refuter/overview_spans.json", "w"), ensure_ascii=False, indent=1)

print("\n== EDITION CITATIONS -> PAIRS (manifest.json + document_number) ==")
cits = re.findall(r'\((?:see also )?(Foreign Relations of the United States, [^()]*?Document (\d+)), (https://history\.state\.gov/historicaldocuments/(frus[^/\s)]+)/(d\d+))\)', ov)
cits += re.findall(r'\((?:see also )?((?:Volume|Document) [^()]*?Document (\d+)), (https://history\.state\.gov/historicaldocuments/(frus[^/\s)]+)/(d\d+))\)', ov)
cits += re.findall(r'\((Document (\d+)), (https://history\.state\.gov/historicaldocuments/(frus[^/\s)]+)/(d\d+))\)', ov)
seen = set()
for full, num, url, v, d in cits:
    if (full, url) in seen: continue
    seen.add((full, url))
    title = re.sub(r'\s+', ' ', mv[v]['title']) if v in mv else None
    dn = con.execute("SELECT document_number FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    ok_num = dn is not None and str(dn[0]) == num and d == 'd' + num
    print("  %s -> %s/%s | doc_number=%s match=%s | manifest title: %s" % (full[:95], v, d, dn[0] if dn else None, ok_num, title))
print("citations parsed:", len(seen))
# dateline/header of each cited doc for attribution check
print("\n== CITED DOCUMENTS: header | dateline ==")
for v, d in cited:
    r = con.execute("SELECT substr(replace(header,char(10),' '),1,160), coalesce(dateline,''), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    print("  %s/%s | fm=%s ed=%s | %s | %s" % (v, d, r[2], r[3], r[0], r[1]))
