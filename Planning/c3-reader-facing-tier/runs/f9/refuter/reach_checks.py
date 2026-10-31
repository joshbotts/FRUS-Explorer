# Refuter: strict reach of the 25 cited documents against every logged MATCH predicate; V7 test of d116; dead-term test of the
# parameterised terms; M7 decade table; M14 reading count; the two non-document spans' sources; house figure re-derivation.
import sqlite3, json, re, collections
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f9/"
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
c = sqlite3.connect(DB, uri=True)
R = open(RUN + "R_in.txt").read().strip(); RI = open(RUN + "RI_in.txt").read().strip()
Rl = [x.strip("'") for x in R.split(",")]; RIl = [x.strip("'") for x in RI.split(",")]; Il = [v for v in RIl if v not in Rl]
Istr = ",".join(repr(v) for v in Il)
NA = "d.is_front_matter=0 AND d.is_editorial_note=0"
J = "FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid"
fam = json.load(open(RUN + "scan_families.json"))['F']
GAPS = {'POS': '"Department of State"', 'NEG': 'ZZZ_IMPOSSIBLE_ZZZ', 'soft power': '"soft power"', 'soft': 'soft',
        'poll/survey+usia': '(poll OR survey) AND (usia OR usi)', '+japan': '(poll OR survey) AND (usia OR usi) AND (japan OR japanes)',
        'usia+aus/nz': '(usia OR usi) AND (australia OR "new zealand")', 'usia+pacific': '(usia OR usi) AND (micronesia OR fiji OR "trust territory" OR samoa OR guam)',
        'fulbright': 'fulbright', 'fulbright+eval': 'fulbright AND (evaluat OR effect OR impact)',
        'asian mind': '"Asian mind" OR "Oriental mind" OR "Asian mentality" OR "Oriental mentality" OR "Asian psychology" OR "Oriental psychology"',
        'face': '"lose face" OR "loss of face" OR "save face" OR "saving face" OR "face saving"'}
M8 = '(usia OR usi OR propaganda OR psycholog OR "information program") AND (asian OR asia OR "far east" OR "far eastern") AND (attitud OR opinion OR imag OR prestig) AND (effect OR effective OR impact OR assess)'
HI = 'header:(japan OR japanes OR china OR chines OR korea OR vietnam OR vietnames OR asia OR asian OR indonesia OR philippin OR thailand OR lao OR laos OR burma OR "far east" OR pacif OR southeast OR taiwan OR cambodia)'
HR = 'header:(usia OR usi OR "information agency" OR "information service" OR psycholog OR propaganda OR "public affairs" OR "information program" OR "operations coordinating board" OR "psychological strategy board" OR cultur OR "public opinion")'
UNION = 'usia OR usi OR "information program" OR "psychological warfare" OR "Voice of America" OR "public diplomacy" OR "cultural exchange"'
preds = {}
for k, m in fam.items(): preds[f"fam:{k}"] = (m, RI)
for k, m in GAPS.items(): preds[f"gap:{k}"] = (m, RI)
preds["M8 ranked"] = (M8, RI); preds["hdr I"] = (HI, Istr); preds["hdr R"] = (HR, R)
preds["decades union"] = (UNION, ",".join(repr(v) for v in Rl if v not in ('frus1948v06', 'frus1949v07p1')))
print("logged predicates:", len(preds))
for k, (m, _) in preds.items(): print("  ", k, "|", m[:120])

cand = set(tuple(l.strip().split("|")) for l in open(RUN + "candidate_set.txt") if l.strip())
top45 = set()
for l in open(RUN + "ranked1.txt"):
    p = l.split("|")
    if len(p) > 2: top45.add((p[0], p[1]))
asian_census = set(c.execute(f"SELECT d.volume_id, d.document_id {J} WHERE frus_documents MATCH ? AND {NA} AND d.volume_id IN ({RI})", (GAPS['asian mind'],)).fetchall())
# the shares.py sample for usia OR usi: 40 evenly spaced of the hit list sorted by (volume_id, document_id)
rows = c.execute(f"SELECT d.volume_id, d.document_id {J} WHERE frus_documents MATCH 'usia OR usi' AND {NA} AND d.volume_id IN ({RI}) ORDER BY d.volume_id, d.document_id").fetchall()
n = len(rows); step = n / 40; samp40 = set(rows[int(i * step)] for i in range(40))
print("usia OR usi hit list:", n, "sample-40 contains d116:", ('frus1952-54v13p1', 'd116') in samp40)
rows2 = c.execute(f"SELECT d.volume_id, d.document_id {J} WHERE frus_documents MATCH '\"psychological warfare\"' AND {NA} AND d.volume_id IN ({RI}) ORDER BY d.volume_id, d.document_id").fetchall()
n2 = len(rows2); samp40b = set(rows2[int(i * (n2 / 40))] for i in range(40))
print("psychological warfare hit list:", n2, "sample-40 contains d116:", ('frus1952-54v13p1', 'd116') in samp40b)

pairs = [tuple(l.split()) for l in open(RUN + "collection_pairs.txt") if l.strip()]
print("\n[STRICT REACH] per cited document: predicates whose MATCH set (over the logged scope) contains it")
summary = {}
for v, d in pairs:
    hits = []
    for name, (m, vols) in preds.items():
        k = c.execute(f"SELECT COUNT(*) {J} WHERE frus_documents MATCH ? AND {NA} AND d.volume_id IN ({vols}) AND d.volume_id=? AND d.document_id=?", (m, v, d)).fetchone()[0]
        if k: hits.append(name)
    printed = []
    if (v, d) in cand: printed.append("candidate_set(141)")
    if (v, d) in top45: printed.append("ranked top-45")
    if (v, d) in asian_census: printed.append("asian-mind census")
    summary[(v, d)] = (hits, printed)
    print(f"  {v}/{d}: {len(hits)} predicates {hits} | printed sets: {printed}")
print("\n[V7] d116 (frus1952-54v13p1):", summary[('frus1952-54v13p1', 'd116')])

print("\n[DEAD TERMS] each atomic term the session's MATCH strings use, tested alone against the whole index (frus_documents):")
terms = set()
for m, _ in preds.values():
    for t in re.findall(r'"[^"]+"|[A-Za-z_]+', m.replace('header:', '')):
        if t.upper() in ('AND', 'OR', 'NOT'): continue
        terms.add(t)
dead = []
for t in sorted(terms):
    try:
        k = c.execute("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH ?", (t,)).fetchone()[0]
    except Exception as e:
        k = f"ERR {e}"
    if k == 0 or isinstance(k, str): dead.append((t, k))
print("  terms tested:", len(terms), "dead/err:", dead)
print("  vocab lookups in log for stems:", [t for t in ['imag', 'prestig', 'attitud', 'psycholog', 'cultur', 'philippin', 'pacif', 'japanes', 'chines', 'vietnames', 'evaluat', 'effect', 'assess', 'impact'] if c.execute("SELECT COUNT(*) FROM frus_documents_vocab WHERE term=?", (t,)).fetchone()[0]])

print("\n[M7] decade table re-run (R minus frus1948v06, frus1949v07p1):")
Rx = [v for v in Rl if v not in ('frus1948v06', 'frus1949v07p1')]; ph = ",".join(repr(v) for v in Rx)
JJ = "FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id"
num = collections.defaultdict(dict)
for dec, v, k in c.execute(f"SELECT substr(dd.date_iso,1,3)||'0s', d.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH ? AND {NA} AND d.volume_id IN ({ph}) GROUP BY 1,2", (UNION,)):
    num[dec][v] = k
rden = dict(c.execute(f"SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) {JJ} WHERE {NA} AND d.volume_id IN ({ph}) GROUP BY 1").fetchall())
cden = dict(c.execute(f"SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) {JJ} WHERE {NA} AND dd.date_iso IS NOT NULL GROUP BY 1").fetchall())
for dec in sorted(num):
    k = sum(num[dec].values()); tv = max(num[dec], key=num[dec].get)
    print(f"  {dec} {k} R_den {rden.get(dec)} per1000_R {1000*k/rden[dec]:.1f} corpus_den {cden.get(dec)} per1000_corpus {1000*k/cden[dec]:.1f} top {tv} {num[dec][tv]} of {k}")

print("\n[M14] reading lists:")
rl = []
for f in ("reading_list.txt", "reading_list2.txt", "reading_list3.txt", "reading_list4.txt"):
    rl += [tuple(l.split()) for l in open(RUN + f) if l.strip()]
print("  total listed:", len(rl), "distinct:", len(set(rl)))
r = c.execute("SELECT is_editorial_note, substr(header,1,60) FROM document_cache WHERE volume_id='frus1955-57v09' AND document_id='d184'").fetchone()
print("  frus1955-57v09/d184 editorial note?", r)
tot = c.execute(f"SELECT SUM(length(body_text)) FROM document_cache WHERE (volume_id||'/'||document_id) IN ({','.join(repr(v+'/'+d) for v,d in rl)})").fetchone()
print("  sum length(body_text) over the listed docs:", tot, "(memo 658,318 over 61)")
quoted = set(pairs); print("  collection docs all in reading lists:", quoted <= set(rl))

print("\n[non-document spans] 'South and Southeast Asia' volume title; 'cultural relations program' chapter heading:")
man = json.load(open(RES + "manifest.json"))
print("  ", [(m['volumeId'], re.sub(r'\s+', ' ', m['title'])) for m in man if m['volumeId'] == 'frus1958-60v15'])
k = 0
for vid, sj in c.execute("SELECT volume_id, structure_json FROM volume_structures WHERE volume_id LIKE 'frus194%'"):
    if 'ultural relations program' in sj: k += 1; print("   heading in", vid)
print("  volumes with 'cultural relations program' heading (1940s):", k)

print("\n[house figure] pointed-at channel's earliest dated row:", c.execute("SELECT MIN(dd.date_iso) FROM external_citations e JOIN document_dates dd ON dd.volume_id=e.volume_id AND dd.document_id=e.document_id").fetchone(),
      "| rows before 1910-12-06:", c.execute("SELECT COUNT(*) FROM external_citations e JOIN document_dates dd ON dd.volume_id=e.volume_id AND dd.document_id=e.document_id WHERE dd.date_iso<'1910-12-06'").fetchone())

print("\n[M12] pointed-at over the 141: unattributed Department of State rows")
cnt = collections.Counter(); docs = collections.defaultdict(set)
for v, d in sorted(cand):
    for row in c.execute("SELECT repository, collection, lot_file_norm FROM external_citations WHERE volume_id=? AND document_id=?", (v, d)):
        cnt[row] += 1; docs[row].add((v, d))
for key in [('Department of State', None, None), ('Department of State', None, '62D430'), ('Department of State', None, '66D95'), ('Department of State', None, '67D54')]:
    print("  ", key, "rows", cnt[key], "docs", len(docs[key]))
print("\n[M16] pointed-at rows for the 25:", sum(c.execute("SELECT COUNT(*) FROM external_citations WHERE volume_id=? AND document_id=?", (v, d)).fetchone()[0] for v, d in pairs),
      "on docs:", [f"{v}/{d}" for v, d in pairs if c.execute("SELECT COUNT(*) FROM external_citations WHERE volume_id=? AND document_id=?", (v, d)).fetchone()[0]])
