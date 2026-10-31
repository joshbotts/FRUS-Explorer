# numbers_check.py: re-run the memo's queries behind the overview's figures (the first five and the rest).
import sqlite3, re, json, sys, csv, collections
sys.path.insert(0, '/Users/jbotts/frus-analysis/c3f/runs/f5')
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f5/"
c = sqlite3.connect(DB, uri=True)
SCOPE = open(RUN + "h.py").read().split('SCOPE = """')[1].split('"""')[0].split()
print("SCOPE volumes in h.py:", len(SCOPE), "distinct:", len(set(SCOPE)))
ph = ",".join("?" * len(SCOPE))
NA = "d.is_front_matter=0 AND d.is_editorial_note=0"

def one(sql, p=()):
    return c.execute(sql, p).fetchone()

print("\n[canary] ", one("SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache"))
print("[scope presence] rows:", one(f"SELECT COUNT(*) FROM (SELECT volume_id FROM document_cache WHERE volume_id IN ({ph}) GROUP BY volume_id)", SCOPE), "docs:", one(f"SELECT COUNT(*) FROM document_cache WHERE volume_id IN ({ph})", SCOPE))
print("[scope non-apparatus] 38,059 claimed:", one(f"SELECT COUNT(*) FROM document_cache d WHERE volume_id IN ({ph}) AND {NA}", SCOPE))
print("[Ed2 volumes in scope]:", [v for v in SCOPE if v.endswith("Ed2")])

# H1: "soft power" never appears (0 documents, all 553 volumes)
sp = one(f"SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH '\"soft power\"' AND {NA}")
sp_all = one("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH '\"soft power\"'")
sp_like = one("SELECT COUNT(*) FROM document_cache WHERE lower(header||' '||coalesce(dateline,'')||' '||coalesce(source_note,'')||' '||body_text) LIKE '%soft power%' OR lower(body_text) LIKE '%soft-power%'")
print("\n[H1] \"soft power\" FTS non-apparatus:", sp, "| FTS incl. apparatus:", sp_all, "| LIKE 'soft power'/'soft-power' any row:", sp_like)
sap = one(f"SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH 'soft AND power' AND {NA}")
print("[relaxed] soft AND power (785 claimed):", sap)
rows = c.execute(f"SELECT d.header,d.dateline,d.source_note,d.body_text FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH 'soft AND power' AND {NA}").fetchall()
lit = sum(1 for r in rows if re.search(r'soft[\s-]+power', ' '.join(x or '' for x in r), re.I))
print("[relaxed] literal soft[\\s-]+power among them (0 claimed):", lit)

# H2: 31 documents
col = json.load(open(RUN + "collection.fruscollection"))
docs = [(e['volumeId'], e['documentId']) for e in col['entries'] if e['kind'] == 'document']
print("\n[H2] collection document entries:", len(docs), "distinct:", len(set(docs)))
years = [one("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?", [v, d])[0] for v, d in docs]
print("     document dates span:", min(years), "to", max(years))
vols = sorted({v for v, d in docs})
print("     volumes of the 31:", len(vols), vols)

# H3-H5: came-from channel for the 31 (memo M7)
print("\n[H3-5] document_sources for the 31:")
tally = collections.Counter()
for v, d in docs:
    r = one("SELECT repository, record_group, lot_file, citation_era, raw_text FROM document_sources WHERE volume_id=? AND document_id=?", [v, d])
    if r is None:
        key = "NO SOURCE ROW"
    else:
        repo, rg, lot, era, raw = r
        if rg == '59' and era in ('decimal', 'cfpf'): key = "RG59 central files (decimal/cfpf)"
        elif rg == '59' and era == 'lot_file': key = f"RG59 lot file"
        elif rg == '306': key = "RG306 USIA"
        elif rg == '305': key = "RG305 as printed"
        elif rg == '84': key = "RG84 embassy"
        elif rg == '34': key = "RG34 as printed (embassy)"
        elif repo == 'Johnson Library': key = "Johnson Library"
        elif repo == 'Nixon Presidential Materials': key = "Nixon Presidential Materials"
        else: key = f"other: {repo}/{rg}/{era}"
    tally[key] += 1
    print(f"   {v}/{d}: {key}  {(r[4][:80] if r else '')}")
for k, n in tally.most_common(): print(f"   {n:2d} {k}")
print("   sum:", sum(tally.values()))
lots = collections.Counter()
for v, d in docs:
    r = one("SELECT lot_file, lot_file_norm FROM document_sources WHERE volume_id=? AND document_id=? AND record_group='59' AND citation_era='lot_file'", [v, d])
    if r: lots[r[0]] += 1
print("   lot files among the six:", dict(lots))

# the rest of the bottom line's numbers
print("\n[M4] public diplomacy:")
pd = one(f"SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH '\"public diplomacy\"' AND {NA}")
pdv = c.execute(f"SELECT d.volume_id FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH '\"public diplomacy\"' AND {NA}").fetchall()
late = sum(1 for (v,) in pdv if v.startswith('frus1977') or v.startswith('frus1981'))
print("   211 claimed:", pd, "| 175 of them 1977+/1981+ claimed:", late, "| by volume:", collections.Counter(v for (v,) in pdv).most_common(8))
pd77 = one(f"SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH '\"public diplomacy\"' AND {NA} AND f.volume_id IN ({ph})", SCOPE)
print("   in the 77 volumes (2 claimed, FTS):", pd77)
rows = c.execute(f"SELECT d.header,d.dateline,d.source_note,d.body_text FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH '\"public diplomacy\"' AND {NA}").fetchall()
strict = sum(1 for r in rows if re.search(r'\bpublic diplomacy\b', ' '.join(x or '' for x in r)))
tol = sum(1 for r in rows if re.search(r'public\W+diplomacy', ' '.join(x or '' for x in r), re.I))
print("   STRICT regex share (210 of 211 claimed):", strict, "| TOLERANT (211):", tol)
hm = one(f"SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH '\"hearts and minds\"' AND {NA}")
print("   hearts and minds corpus (60 in zero_and_relaxed.txt):", hm)

# positive control: Department of State in every one of the 77 volumes (FTS form)
dos = c.execute(f"SELECT f.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH '\"Department of State\"' AND {NA} AND f.volume_id IN ({ph}) GROUP BY f.volume_id", SCOPE).fetchall()
print("\n[M3 controls] FTS 'Department of State': volumes with hits", len(dos), "of 77; docs", sum(n for _, n in dos))
zz = one(f"SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ' AND {NA}")
print("   ZZZ_IMPOSSIBLE_ZZZ:", zz)

# M10: 11 of 698 series before 1940
sf = json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/series-facts-index.json"))
print("\n[M10] series-facts keys:", list(sf.keys())[:8])
by = sf.get('byNaId') or {}
leg = sf.get('legend') or {}
print("   legend:", leg)
# find the start-year key
sample = next(iter(by.values()))
print("   sample row:", sample)
ykey = None
for k, v in leg.items():
    if 'start' in str(v).lower() and 'year' in str(v).lower(): ykey = k
print("   start-year key guess:", ykey)
if ykey:
    ys = [r.get(ykey) for r in by.values() if isinstance(r, dict) and r.get(ykey) is not None]
    print("   rows:", len(by), "with a start year:", len(ys), "before 1940:", sum(1 for y in ys if int(y) < 1940))

# M11: USIA in the pointed-at channel
u = one("SELECT COUNT(*) FROM external_citations WHERE raw_text LIKE '%RG 306%' OR raw_text LIKE '%Information Agency%' OR collection LIKE '%Information Agency%' OR repository LIKE '%Information Agency%'")
print("\n[M11] USIA pointers in external_citations (11 claimed):", u)
print("   RG306 came-from whole index (427,427 claimed):", one("SELECT COUNT(*), COUNT(DISTINCT volume_id||'/'||document_id) FROM document_sources WHERE record_group='306'"))

# section 3: 95 retrieved
ft = [l.split('\t') for l in open(RUN + "fetched.tsv") if l.strip()]
print("\n[sec 3] fetched.tsv rows:", len(ft), "distinct pairs:", len({(r[0], r[1]) for r in ft}), "OK:", sum(1 for r in ft if r[4] == 'OK'))
import os
print("   docs/ files:", len([f for f in os.listdir(RUN + 'docs') if f.endswith('.txt')]))

# facts quoted in prose: 80 million, fourteen steps, 28 top leaders, 65%
def body(v, d): return re.sub(r'\s+', ' ', one("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?", [v, d])[0])
b = body("frus1952-54v12p2", "d251")
m = re.search(r'.{200}2\.5 percent.{250}', b)
print("\n[fact] d251 2.5 percent context:", m.group(0) if m else None)
print("   '80 million' / '80,000,000' in d251:", bool(re.search(r'80[, ]?(million|000,000)', b)))
b = body("frus1964-68v01", "d177")
nums = re.findall(r'(?<![\d.])(\d{1,2})\.\s', b)
print("[fact] d177 numbered items found:", nums[:20])
seg = b[b.find('I have'):b.find('Following are more details')] if 'Following are more details' in b else b
print("   items 1..14 present in the 'I have' .. 'Following are more details' span:", all(re.search(rf'(?<![\d.]){i}\.\s', seg) for i in range(1, 15)), "15. present:", bool(re.search(r'(?<![\d.])15\.\s', seg)))
b = body("frus1955-57v22", "d484")
m = re.search(r'.{120}28 .{120}', b)
print("[fact] d484 '28' context:", m.group(0) if m else None)
b = body("frus1952-54v12p2", "d359")
m = re.search(r'.{150}65%.{80}', b)
print("[fact] d359 65% context:", m.group(0) if m else None)
