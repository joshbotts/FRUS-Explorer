# reach_check.py: for every document the overview cites, which logged full-text / heading query returns it.
import sqlite3, re, json, csv, sys
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f5/"
c = sqlite3.connect(DB, uri=True)
SCOPE = open(RUN + "h.py").read().split('SCOPE = """')[1].split('"""')[0].split()
FUNC = re.search(r'FUNC="([^"]+)"', open(RUN + "scan.py").read()).group(1).split()
PUBDIP = ["frus1917-72PubDipv06", "frus1917-72PubDipv07", "frus1917-72PubDipv08"]
ph = ",".join("?" * len(SCOPE))
NA = "d.is_front_matter=0 AND d.is_editorial_note=0"

ov = open(RUN + "overview.md").read()
cited = [('frus1952-54v12p2','d352'),('frus1961-63v04','d81'),('frus1964-68v02','d160'),('frus1964-68v26','d106'),('frus1917-72PubDipv08','d99'),('frus1977-80v30','d79')]  # quoted in the overview's prose without a URL citation
print("documents cited in the overview (URLs):", len(cited))
col = json.load(open(RUN + "collection.fruscollection"))
inc = {(e['volumeId'], e['documentId']) for e in col['entries'] if e['kind'] == 'document'}
print("  in the collection:", sum(1 for p in cited if p in inc), "not in:", [p for p in cited if p not in inc])

# the logged MATCH terms over the 77-volume scope (queries.log lines 10-49, counts) and the union (line 50)
TERMS = ['"soft power"', 'USIA', 'USIS', '"information agency"', '"information service"', '"information program"', '"psychological warfare"', '"psychological operations"', '"psychological strategy"', '"cultural exchange"', '"educational exchange"', '"exchange of persons"', 'Fulbright', '"Voice of America"', 'propaganda', 'prestige', '"hearts and minds"', '"image of the United States"', '"Department of State"', 'ZZZ_IMPOSSIBLE_ZZZ']
CONTROL = {'"Department of State"', 'ZZZ_IMPOSSIBLE_ZZZ'}
UNION = 'USIA OR USIS OR "information agency" OR "information service" OR "information program" OR "psychological warfare" OR "psychological operations" OR "psychological strategy" OR "cultural exchange" OR "educational exchange" OR "exchange of persons" OR "Voice of America" OR "hearts and minds" OR "image of the United States" OR propaganda OR prestige OR Fulbright'
HEADER_LIKE = "(header LIKE '%information program%' OR header LIKE '%USIA%' OR header LIKE '%USIS%' OR header LIKE '%information agency%' OR header LIKE '%information service%' OR header LIKE '%psychological%' OR header LIKE '%cultural%' OR header LIKE '%propaganda%' OR header LIKE '%exchange of%' OR header LIKE '%educational exchange%' OR header LIKE '%Voice of America%' OR header LIKE '%Fulbright%' OR header LIKE '%information activit%' OR header LIKE '%information policy%' OR header LIKE '%image%' OR header LIKE '%prestige%')"
NEARS = ['NEAR("information program" effectiveness, 15)', 'NEAR(USIS effectiveness, 10)']
JAPAN = ["frus1958-60v18", "frus1961-63v22", "frus1964-68v29p2", "frus1969-76v19p2", "frus1955-57v23p1"]
JAPANQ = 'USIS OR USIA OR "cultural exchange" OR "educational exchange" OR "information program" OR propaganda'

def matches(v, d, q):
    return c.execute(f"SELECT 1 FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH ? AND {NA} AND f.volume_id=? AND f.document_id=?", [q, v, d]).fetchone() is not None

csv.field_size_limit(10**9)
scan = {(r['volume_id'], r['document_id']): r for r in csv.DictReader(open(RUN + "scan_docs.tsv"), delimiter='\t')}
pub = {}
for l in open(RUN + "pubdip_scan.tsv"):
    f = l.rstrip('\n').split('\t')
    pub[(f[0], f[1])] = dict(len=int(f[2]), R=int(f[3]), hR=int(f[4]), A=int(f[5]), C=int(f[6]), D=int(f[7]))
print("pubdip rows selected by R>=8 or hR>=1 (114 claimed):", sum(1 for r in pub.values() if r['R'] >= 8 or r['hR'] >= 1), "of", len(pub))

# the memo's vector-only claim and its account of where each document came from
VEC_ONLY = {("frus1917-72PubDipv08", "d99"), ("frus1977-80v22", "d104")}
VEC_LED = {("frus1917-72PubDipv07", "d32"), ("frus1917-72PubDipv07", "d85"), ("frus1917-72PubDipv08", "d31"), ("frus1917-72PubDipv08", "d149")}

summary = []
for v, d in cited:
    hits = []
    in_scope = v in SCOPE
    if in_scope:
        for t in TERMS:
            if matches(v, d, t): hits.append(f"MATCH {t}" + (" [control]" if t in CONTROL else ""))
        if matches(v, d, UNION): hits.append("MATCH union-by-volume (line 50)")
        r = c.execute(f"SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0 AND {HEADER_LIKE}", [v, d]).fetchone()
        if r: hits.append("header LIKE (line 52)")
        for q in NEARS:
            if matches(v, d, q): hits.append(f"NEAR {q}")
    if v in JAPAN and matches(v, d, JAPANQ): hits.append("Japan volumes MATCH (line 74)")
    # corpus-wide logged MATCH predicates (COUNT queries, lines 11..49 odd; 93-98)
    corpus_hits = []
    for t in TERMS:
        if matches(v, d, t): corpus_hits.append(t)
    for t in ['soft AND power', '"public diplomacy"', '"hearts and minds"']:
        if matches(v, d, t): corpus_hits.append(t + " [hit list 97/98]" if t != '"hearts and minds"' else t)
    # regex scan rows
    s = scan.get((v, d)); p = pub.get((v, d))
    scan_note = ""
    if s:
        scan_note = f"scan.py A={s['A']} Adistinct={s['Adistinct']} R={s['R']} -> beliefs set(A>=2&R>=2)={int(s['A'])>=2 and int(s['R'])>=2}, ranked/topic-slice(Adistinct>=2&R>=2)={int(s['Adistinct'])>=2 and int(s['R'])>=2}"
        if int(s['A']) >= 2 and int(s['R']) >= 2: hits.append("scan.py filter A>=2&R>=2 (beliefs.py, 1,608 docs)")
        if int(s['Adistinct']) >= 2 and int(s['R']) >= 2: hits.append("scan.py filter Adistinct>=2&R>=2 (ranked.txt / topic slice)")
    if p:
        scan_note = f"pubdip scan R={p['R']} hR={p['hR']} A={p['A']} -> selected(R>=8 or hR>=1)={p['R']>=8 or p['hR']>=1}"
        if p['R'] >= 8 or p['hR'] >= 1: hits.append("PubDip regex scan filter R>=8 or hR>=1 (114 docs; topic slice)")
    substantive = [h for h in hits if "[control]" not in h]
    status = "VECTOR-ONLY claimed" if (v, d) in VEC_ONLY else ("vector-led, regex-found claimed" if (v, d) in VEC_LED else "full-text claimed")
    summary.append((v, d, status, hits, corpus_hits, scan_note))
    print(f"\n{v}/{d}  [{status}]  in 77-scope={in_scope}")
    print("   logged scope/heading queries returning it:", hits if hits else "NONE")
    print("   corpus-wide logged MATCH predicates it satisfies:", corpus_hits if corpus_hits else "NONE")
    print("  ", scan_note)
    print("   substantive (non-control) logged query returns it:", bool(substantive))

print("\n== STRICT verdicts ==")
for v, d, status, hits, corpus_hits, _ in summary:
    any_logged = bool(hits) or bool(corpus_hits)
    subst = bool([h for h in hits if "[control]" not in h]) or bool([t for t in corpus_hits if t not in CONTROL])
    print(f"  {v}/{d}: any logged full-text query returns it={any_logged}; a non-control query returns it={subst}; memo: {status}")
