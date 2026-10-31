#!/usr/bin/env python3
"""Refuter re-runs for cell f1: headline numbers, zeros, reach. Read-only DB."""
import sqlite3, re, json, csv, os, sys
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f1"
OUT = RUN + "/refuter"
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c = sqlite3.connect(DB, uri=True)

def q(sql, params=()):
    return c.execute(sql, params).fetchall()

def show(label, sql, params=()):
    r = q(sql, params)
    print(f"[{label}] {sql if len(sql) < 400 else sql[:400] + ' …'}\n   -> {r}")
    return r

print("=== M0.1 coverage ===")
show("M0.1", "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache")
show("non-apparatus", "SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0")

print("\n=== M0.3 / M0.4 / M1.1 controls ===")
BASE = ("SELECT COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d "
        "ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH ? "
        "AND d.is_front_matter=0 AND d.is_editorial_note=0")
for t in ['"department of state"', 'ZZZ_IMPOSSIBLE_ZZZ', '"soft power"', 'messaging', 'audience',
          'USIA', 'USIS', '"information program"', '"psychological warfare"', '"psychological strategy"',
          'propaganda', '"voice of america"', '"american image"', '"image of the united states"',
          '"cultural exchange"', '"public diplomacy"', '"public opinion"']:
    show(f"M1.1 {t}", BASE, (t,))
show("M0.3 missing volume", "SELECT DISTINCT volume_id FROM document_cache WHERE volume_id NOT IN (SELECT d.volume_id FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH '\"department of state\"' AND d.is_front_matter=0 AND d.is_editorial_note=0)")
# relaxed forms of soft power, for the record
for t in ['soft', 'power', 'soft AND power', '"soft-power"']:
    show(f"relaxed soft power: {t}", BASE, (t,))

print("\n=== M1.2 false friends (PD volumes vs corpus) ===")
PD = "('frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1977-80v30')"
for t in ['"soft power"', 'messaging', 'audience', '"department of state"']:
    show(f"M1.2 {t}", f"SELECT SUM(d.volume_id IN {PD}), (SELECT COUNT(*) FROM document_cache WHERE volume_id IN {PD} AND is_front_matter=0 AND is_editorial_note=0), COUNT(*), (SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0", (t,))
show("M1.2 literal messaging", "SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND body_text LIKE '%messaging%'")
show("M1.2 literal messaging (which)", "SELECT volume_id||'/'||document_id FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND body_text LIKE '%messaging%'")
show("literal messaging incl. apparatus", "SELECT COUNT(*) FROM document_cache WHERE body_text LIKE '%messaging%'")
show("literal 'soft power' LIKE, all surfaces", "SELECT COUNT(*) FROM document_cache WHERE (header||' '||coalesce(dateline,'')||' '||coalesce(source_note,'')||' '||body_text) LIKE '%soft power%'")

print("\n=== M1.5 scope set ===")
INFO = '(USIA OR USIS OR "information program" OR "psychological warfare" OR "psychological strategy" OR "psychological operations" OR "voice of america" OR "public diplomacy" OR "cultural exchange" OR "information agency" OR "information activities" OR "image of the united states" OR "american image" OR "U.S. image")'
GEO = '(asia OR asian OR "far east" OR japan OR japanese OR china OR chinese OR korea OR korean OR vietnam OR vietnamese OR indochina OR philippines OR indonesia OR thailand OR laos OR cambodia OR burma OR malaya OR malaysia OR singapore OR taiwan OR australia OR pacific)'
SCOPE_SQL = f"""SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH '{INFO} AND {GEO}' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND dd.date_iso>='1945-01-01' AND dd.date_iso<'1981-01-01' ORDER BY d.volume_id, d.document_id"""
hits = q(SCOPE_SQL)
print("scope set:", len(hits), "docs in", len({v for v, _ in hits}), "volumes")
session_hits = json.load(open(RUN + "/scope_hits.json"))
print("equals session's scope_hits.json:", [list(h) for h in hits] == session_hits, "(session n =", len(session_hits), ")")

print("\n=== M1.7 census (my own implementation of the memo's tolerant rule) ===")
SEP = r'[\s\-,().]+'
fam = [['USIA'], ['USIS'], ['USIE'], ['information', 'program'], ['psychological', 'warfare'], ['psychological', 'strateg'],
       ['psychological', 'operation'], ['voice', 'of', 'america'], ['public', 'diplomac'], ['cultural', 'exchange'],
       ['information', 'agenc'], ['information', 'activit'], ['image', 'of', 'the', 'united', 'states'], ['american', 'image'], ['U', 'S', 'image']]
info_tol = re.compile(r'\b(' + '|'.join(SEP.join(w + r'\w*' for w in f) for f in fam) + r')', re.I)
geo = re.compile(r'\b(asia\w*|far east|japan\w*|chin\w*|korea\w*|viet\s*-?nam\w*|indochin\w*|philippine\w*|indonesia\w*|thai\w*|lao\w*|cambodia\w*|burm\w*|malay\w*|singapore|taiwan\w*|australia\w*|pacific)\b', re.I)
usi = re.compile(r'\bUSI\b')
usoi = re.compile(r'united states of indonesia', re.I)
both = 0; lack = 0; lack_usi = 0; usi_vols = {}; spell = 0; confirmed = []
for v, d in hits:
    row = c.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    t = re.sub(r'\s+', ' ', ' '.join(x or '' for x in row))
    a = bool(info_tol.search(t)); g = bool(geo.search(t)); u = bool(usi.search(t))
    if a and g:
        both += 1; confirmed.append((v, d))
    if not a:
        lack += 1
        if u:
            lack_usi += 1; usi_vols[v] = usi_vols.get(v, 0) + 1
            if usoi.search(t): spell += 1
print(f"both families: {both} of {len(hits)}; lacking info literal: {lack}; of which bare USI: {lack_usi}; spell out United States of Indonesia: {spell}")
print("USI volume spread:", sorted(usi_vols.items(), key=lambda x: -x[1]))
print("confirmed set volumes:", len({v for v, _ in confirmed}))
print("share:", round(100.0 * both / len(hits), 1), "per 100")
sess_conf = [tuple(r) for r in csv.reader(open(RUN + "/scope_confirmed.csv"))]
print("equals session's scope_confirmed.csv:", sorted(confirmed) == sorted(sess_conf), "(session n =", len(sess_conf), ")")
from collections import Counter
vc = Counter(v for v, _ in confirmed)
print("top 12 volumes of confirmed:", vc.most_common(12))
print("frus1949v08:", vc.get('frus1949v08'), "frus1955-57v03mSupp:", vc.get('frus1955-57v03mSupp'))

print("\n=== M1.6 sample of 40 (STRICT/TOLERANT), re-run ===")
step = len(hits) / 40; sample = [hits[int(k * step)] for k in range(40)]
info_strict = re.compile(r'\b(USIA|USIS|information program|psychological warfare|psychological strategy|psychological operations|voice of america|public diplomacy|cultural exchange|information agency|information activities|image of the united states|american image|U\.S\. image)\b', re.I)
fam_noUSIE = [f for f in fam if f != ['USIE']]
info_tol2 = re.compile(r'\b(' + '|'.join(SEP.join(w + r'\w*' for w in f) for f in fam_noUSIE) + r')', re.I)
ns = nt = ng = 0; miss = []
for v, d in sample:
    r = c.execute("SELECT header||' '||coalesce(dateline,'')||' '||coalesce(source_note,'')||' '||body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()[0]
    t = re.sub(r'\s+', ' ', r)
    s = bool(info_strict.search(t)); tt = bool(info_tol2.search(t)); g = bool(geo.search(t))
    ns += s and g; nt += tt and g; ng += g
    if not (tt and g): miss.append((v, d))
print(f"STRICT {ns}/40, TOLERANT {nt}/40, geo {ng}/40, misses {miss}")

print("\n=== M1.8 decade shape re-run ===")
for r in q(f"""WITH hits AS (SELECT d.volume_id v, d.document_id i, substr(dd.date_iso,1,3) dec FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH '{INFO} AND {GEO}' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')), base AS (SELECT substr(dd.date_iso,1,3) dec, COUNT(*) n FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') GROUP BY 1) SELECT h.dec||'0s', COUNT(*), b.n, round(1000.0*COUNT(*)/b.n,1), (SELECT MAX(c) FROM (SELECT COUNT(*) c FROM hits h2 WHERE h2.dec=h.dec GROUP BY h2.v)) topvol FROM hits h JOIN base b ON b.dec=h.dec GROUP BY h.dec ORDER BY h.dec"""):
    print("  ", r)

print("\n=== Argument set (22) and the overview's 21 cited pairs ===")
argset = [tuple(r) for r in csv.reader(open(RUN + "/argset.csv"))]
print("argset n:", len(argset), "distinct:", len(set(argset)))
cited = [("frus1950v06", "d50"), ("frus1917-72PubDipv07", "d73"), ("frus1952-54v13p1", "d116"), ("frus1917-72PubDipv08", "d88"),
         ("frus1969-76v38p2", "d105"), ("frus1952-54v12p2", "d403"), ("frus1955-57v09", "d190"), ("frus1955-57v22", "d447"),
         ("frus1961-63v01", "d49"), ("frus1961-63v01", "d265"), ("frus1917-72PubDipv06", "d140"), ("frus1917-72PubDipv06", "d126"),
         ("frus1917-72PubDipv08", "d31"), ("frus1917-72PubDipv08", "d149"), ("frus1917-72PubDipv07", "d85"), ("frus1917-72PubDipv07", "d32"),
         ("frus1969-76v19p2", "d67"), ("frus1964-68v27", "d386"), ("frus1917-72PubDipv08", "d58"), ("frus1917-72PubDipv08", "d99"),
         ("frus1977-80v30", "d79")]
print("cited n:", len(cited), "distinct:", len(set(cited)))
print("cited ⊆ argset:", set(cited) <= set(argset), "argset − cited:", set(argset) - set(cited))
scope_set = set(hits); conf_set = set(confirmed)
print("argset ⊆ scope(2860):", set(argset) <= scope_set, "argset ⊆ confirmed(2692):", set(argset) <= conf_set)
print("cited ⊆ scope(2860):", set(cited) <= scope_set, "missing:", set(cited) - scope_set)
# dates and volumes of the 22
rows = q("SELECT d.volume_id||'/'||d.document_id, dd.date_iso FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE (d.volume_id,d.document_id) IN (VALUES " + ",".join(f"('{v}','{d}')" for v, d in argset) + ") ORDER BY dd.date_iso")
print("argset dates:", rows[0], "…", rows[-1])
print("argset volumes:", sorted({v for v, _ in argset}), len({v for v, _ in argset}))

print("\n=== Header query (log line 30) and BM25 query (log line 32): which cited pairs do they return? ===")
HDR = f"""SELECT d.volume_id||'/'||d.document_id FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH 'header:(USIA OR USIS OR information OR propaganda OR psychological OR "voice of america" OR "public diplomacy" OR cultural OR image OR opinion OR prestige) AND {INFO} AND {GEO}' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso>='1945' ORDER BY dd.date_iso"""
hdr = [r[0] for r in q(HDR)]
print("header query rows:", len(hdr), "(session: 330)")
BM = """SELECT d.volume_id||'/'||d.document_id FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH '(USIA OR USIS OR "information program" OR "psychological warfare" OR "psychological strategy" OR "psychological operations" OR "voice of america" OR "cultural exchange" OR "information agency" OR "information activities" OR "image of the united states" OR "american image" OR "U.S. image")' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ('frus1950v06','frus1951v06p1','frus1951v06p2','frus1952-54v12p1','frus1952-54v12p2','frus1952-54v13p1','frus1952-54v14p1','frus1952-54v14p2','frus1955-57v21','frus1955-57v22','frus1955-57v23p1','frus1955-57v03','frus1958-60v15','frus1958-60v16','frus1958-60v17','frus1958-60v18','frus1958-60v19','frus1964-68v26','frus1964-68v27','frus1964-68v29p2','frus1964-68v30','frus1969-76v19p2','frus1969-76v20','frus1977-80v22','frus1969-76ve12') ORDER BY bm25(frus_documents) ASC LIMIT 40"""
bm = [r[0] for r in q(BM)]
print("bm25 rows:", len(bm))
sess_hdr = [l.split('|')[0] for l in open(RUN + "/header_hits.txt") if l.strip()]
sess_bm = [l.split('|')[0] for l in open(RUN + "/ea_bm25.txt") if l.strip()]
print("header rows equal session's:", hdr == sess_hdr, "; bm25 rows equal session's:", bm == sess_bm)
hdr_set = set(hdr); bm_set = set(bm)
readlist = [l.strip() for l in open(RUN + "/readlist.txt") if l.strip()]
for v, d in cited:
    k = f"{v}/{d}"
    print(f"  {k:30s} scope:{(v,d) in scope_set!s:5} header:{k in hdr_set!s:5} bm25:{k in bm_set!s:5} readlist46:{k in readlist!s:5}")

print("\n=== M4.1 / M4.2 over the confirmed set (TEMP table on the ro connection) ===")
c.execute("CREATE TEMP TABLE s(v TEXT, d TEXT)")
c.executemany("INSERT INTO s VALUES(?,?)", confirmed)
print("s size", q("SELECT COUNT(*) FROM s"))
Q1 = "SELECT coalesce(ds.repository,'?'),coalesce(ds.record_group,'-'),coalesce(ds.lot_file_norm,'-'),coalesce(substr(ds.series_name,1,60),'-'),ds.citation_era,COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.v AND ds.document_id=s.d GROUP BY 1,2,3,4,5 ORDER BY 6 DESC LIMIT 25"
for r in q(Q1): print("  came-from", r)
print("docs with a document_sources row:", q("SELECT COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.v AND ds.document_id=s.d"))
print("came-from by lot_file_norm (all lots):", q("SELECT ds.lot_file_norm, COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.v AND ds.document_id=s.d WHERE ds.lot_file_norm IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 8"))
Q2 = "SELECT coalesce(ec.repository,'?'),coalesce(substr(ec.collection,1,60),'-'),coalesce(ec.lot_file_norm,'-'),ec.anchor,COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM s JOIN external_citations ec ON ec.volume_id=s.v AND ec.document_id=s.d GROUP BY 1,2,3,4 ORDER BY 5 DESC LIMIT 20"
for r in q(Q2): print("  pointed-at", r)
print("pointed-at by lot_file_norm (all lots):", q("SELECT ec.lot_file_norm, COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM s JOIN external_citations ec ON ec.volume_id=s.v AND ec.document_id=s.d WHERE ec.lot_file_norm IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 8"))
print("series 2839192 lots combined (63D351+66D95): came-from", q("SELECT COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.v AND ds.document_id=s.d WHERE ds.lot_file_norm IN ('63D351','66D95')"),
      "pointed-at distinct docs", q("SELECT COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM s JOIN external_citations ec ON ec.volume_id=s.v AND ec.document_id=s.d WHERE ec.lot_file_norm IN ('63D351','66D95')"))

print("\n=== M4.3 argument set (22) sources and pointed-at ===")
c.execute("CREATE TEMP TABLE a(v TEXT, d TEXT)")
c.executemany("INSERT INTO a VALUES(?,?)", argset)
for r in q("SELECT a.v||'/'||a.d, ds.repository, ds.record_group, ds.lot_file_norm, ds.series_name, ds.citation_era, ds.decimal_class FROM a LEFT JOIN document_sources ds ON ds.volume_id=a.v AND ds.document_id=a.d ORDER BY 1"):
    print("  src", r)
for r in q("SELECT ec.volume_id||'/'||ec.document_id, ec.anchor, ec.repository, ec.collection, ec.lot_file_norm, ec.decimal_class, substr(ec.raw_text,1,80) FROM a JOIN external_citations ec ON ec.volume_id=a.v AND ec.document_id=a.d ORDER BY 1"):
    print("  ext", r)

print("\n=== M4.2 claim: 'no row before 1910-12-06' ===")
show("min date of external_citations", "SELECT MIN(dd.date_iso), COUNT(*) FROM external_citations ec JOIN document_dates dd ON dd.volume_id=ec.volume_id AND dd.document_id=ec.document_id WHERE dd.date_iso IS NOT NULL")
show("rows before 1910-12-06", "SELECT COUNT(*) FROM external_citations ec JOIN document_dates dd ON dd.volume_id=ec.volume_id AND dd.document_id=ec.document_id WHERE dd.date_iso < '1910-12-06'")

print("\n=== M1.4 manifest scan ===")
man = json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
print("manifest volumes:", len(man))
pd = [(m['filename'], m.get('title', '').replace('\n', ' ')[:90]) for m in man if re.search(r'Public Diplomacy|Information', m.get('title', ''), re.I)]
for p in pd: print("  PD/Info title:", p)
v81 = [m['filename'] for m in man if m['filename'].startswith('frus1981-88')]
print("1981-88 volumes:", len(v81), v81)

print("\n=== M2 reading accounting: 48 raw files equal length(body_text) ===")
ok = 0; tot = 0; n = 0
for fn in sorted(os.listdir(RUN + "/raw")):
    v, d = fn[:-4].split("__")
    head = open(RUN + "/raw/" + fn).read().split("\n---\n", 1)
    bl = int(re.search(r'^BODYLEN: (\d+)', head[0], re.M).group(1))
    L = q("SELECT length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?", (v, d))[0][0]
    body = head[1]
    ok += (bl == L == len(body)); tot += L; n += 1
print(f"raw files: {n}; BODYLEN == length(body_text) == captured body length for {ok}; total {tot}")
print("all 22 argset pairs have a raw file:", all(os.path.exists(f"{RUN}/raw/{v}__{d}.txt") for v, d in argset))

print("\n=== M1.8a survey vocabulary (scoping) ===")
INFO2 = '(USIA OR USIS OR "information program" OR "psychological warfare" OR "psychological strategy" OR "psychological operations" OR "voice of america" OR "public diplomacy" OR "cultural exchange" OR "information agency" OR "information activities")'
GEO2 = '(asia OR asian OR japan OR japanese OR vietnam OR vietnamese OR korea OR thailand OR philippines OR indonesia OR "far east")'
for mid in ['(survey OR surveys OR poll OR polls)', '("office of research")', '("opinion research")']:
    show(f"M1.8a {mid}", "SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0", (f"{INFO2} AND {mid} AND {GEO2}",))

json.dump({"scope_n": len(hits), "confirmed_n": both, "confirmed_vols": len({v for v, _ in confirmed})}, open(OUT + "/sql_summary.json", "w"))
print("\nDONE")
