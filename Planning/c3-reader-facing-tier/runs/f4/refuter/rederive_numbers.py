#!/usr/bin/env python3
"""Refuter re-derivation of the memo's headline numbers (M01..M07) for cell f4."""
import json, sqlite3
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
S = json.load(open('/Users/jbotts/frus-analysis/c3f/runs/f4/scope_sets.json'))
c = sqlite3.connect(DB, uri=True)
c.execute("CREATE TEMP TABLE R(volume_id TEXT PRIMARY KEY)")
c.executemany("INSERT INTO R VALUES (?)", [(v,) for v in S['R']])
c.execute("CREATE TEMP TABLE G(volume_id TEXT PRIMARY KEY)")
c.executemany("INSERT INTO G VALUES (?)", [(v,) for v in S['G']])
print("scope_sets: R =", len(S['R']), "G =", len(S['G']), "overlap =", set(S['R']) & set(S['G']), "Ed2 in R/G:", [v for v in S['R']+S['G'] if v.endswith('Ed2')])

def q(label, sql, params=()):
    r = c.execute(sql, params).fetchall()
    print(f"{label}\n  SQL: {sql}\n  params: {params}\n  -> {r}")
    return r

# M01
q("M01 coverage", "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache")
# M02
q("M02 R all", "SELECT COUNT(DISTINCT d.volume_id), COUNT(*), SUM(d.is_front_matter), SUM(d.is_editorial_note) FROM document_cache d JOIN R USING(volume_id)")
q("M02 R non-apparatus", "SELECT COUNT(DISTINCT d.volume_id), COUNT(*) FROM document_cache d JOIN R USING(volume_id) WHERE d.is_front_matter=0 AND d.is_editorial_note=0")
# M03
q("M03 G non-apparatus", "SELECT COUNT(DISTINCT d.volume_id), COUNT(*) FROM document_cache d JOIN G USING(volume_id) WHERE d.is_front_matter=0 AND d.is_editorial_note=0")
# M04 union
U = '''(USIS OR USIA OR JUSPAO OR "Information Agency" OR "Information Service" OR "psychological warfare" OR "psychological operations" OR "psychological strategy" OR "information program" OR "cultural exchange" OR "educational exchange" OR Fulbright OR "Voice of America" OR "exchange of persons" OR "hearts and minds" OR "cultural program" OR "Asia Foundation" OR "leader grant" OR "information officer" OR "cultural affairs" OR "cultural relations" OR "public diplomacy" OR "information activities")'''
q("M04 union total in R (docs, volumes)", "SELECT COUNT(*), COUNT(DISTINCT f.volume_id), MIN(cnt) FROM (SELECT f.volume_id, COUNT(*) cnt FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ? GROUP BY 1) f", (U,))
q("M04 union total in R (flat count)", "SELECT COUNT(*), COUNT(DISTINCT f.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ?", (U,))
# M06 S1
A = '(Vietnam OR Viet OR Korea OR Japan OR Japanese OR China OR Chinese OR Indonesia OR Philippines OR Thailand OR Laos OR Cambodia OR Asia OR Asian OR Taiwan OR Malaysia OR Singapore OR Pacific)'
HDR = "(d.header LIKE '%Asia%' OR d.header LIKE '%Viet%' OR d.header LIKE '%Japan%' OR d.header LIKE '%China%' OR d.header LIKE '%Chinese%' OR d.header LIKE '%Korea%' OR d.header LIKE '%Indonesia%' OR d.header LIKE '%Philippines%' OR d.header LIKE '%Thai%' OR d.header LIKE '%Pacific%' OR d.header LIKE '%Taiwan%' OR d.header LIKE '%Far East%')"
q("M06 S1 count", f"SELECT COUNT(*), COUNT(DISTINCT f.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN G ON G.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ? AND {HDR}", (A,))
q("M06 S1 per volume", f"SELECT f.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN G ON G.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ? AND {HDR} GROUP BY 1", (A,))
# M07 controls
SQLR = "SELECT COUNT(*), COUNT(DISTINCT f.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND f.frus_documents MATCH ?"
SQLW = "SELECT COUNT(*), COUNT(DISTINCT f.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ?"
for t in ['"Department of State"', 'ZZZ_IMPOSSIBLE_ZZZ', '"soft power"', '"public diplomacy"', '"Radio Free Asia"', '"Asian mentality"']:
    q(f"M07 {t} in R", SQLR, (t,))
    q(f"M07 {t} whole corpus", SQLW, (t,))
# whole corpus including apparatus for soft power (the overview says 'no document of the series')
q('"soft power" whole corpus INCLUDING apparatus', "SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH ?", ('"soft power"',))
q('soft NEAR power (any proximity 3) whole corpus', "SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH ?", ('NEAR(soft power, 3)',))
# literal check of 'soft power' in body text via LIKE (not stemmed)
q("LIKE '%soft power%' in document_cache (all rows)", "SELECT COUNT(*) FROM document_cache WHERE lower(body_text) LIKE '%soft power%' OR lower(header) LIKE '%soft power%'")
# how many of the 76 R volumes have DoS
q("DoS volumes in R", "SELECT COUNT(DISTINCT f.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND f.frus_documents MATCH ?", ('"Department of State"',))
# Date spans
q("R doc date span (document_dates)", "SELECT MIN(dd.date_iso), MAX(dd.date_iso), COUNT(*) FROM document_dates dd JOIN R USING(volume_id) JOIN document_cache d ON d.volume_id=dd.volume_id AND d.document_id=dd.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso IS NOT NULL")
q("G doc date span (document_dates)", "SELECT MIN(dd.date_iso), MAX(dd.date_iso), COUNT(*) FROM document_dates dd JOIN G USING(volume_id) JOIN document_cache d ON d.volume_id=dd.volume_id AND d.document_id=dd.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso IS NOT NULL")
# 1910-12-06 house figure: earliest document carrying an external_citations row
q("earliest document with an external_citations row", "SELECT MIN(dd.date_iso) FROM external_citations e JOIN document_dates dd ON dd.volume_id=e.volume_id AND dd.document_id=e.document_id WHERE dd.date_iso IS NOT NULL")
q("external_citations rows total / docs", "SELECT COUNT(*), COUNT(DISTINCT volume_id||'/'||document_id) FROM external_citations")
# the 22 cited docs' external citations
cited = [("frus1950v06","d50"),("frus1964-68v01","d122"),("frus1917-72PubDipv07","d85"),("frus1969-76v38p2","d105"),("frus1924v01","d540"),("frus1949v09","d558"),("frus1952-54v12p2","d403"),("frus1917-72PubDipv07","d32"),("frus1917-72PubDipv08","d58"),("frus1917-72PubDipv08","d99"),("frus1955-57v22","d447"),("frus1961-63v23","d289"),("frus1964-68v27","d386"),("frus1964-68v02","d160"),("frus1964-68v29p2","d46"),("frus1964-68v26","d106"),("frus1917-72PubDipv08","d31"),("frus1955-57v23p2","d50"),("frus1977-80v30","d79"),("frus1917-72PubDipv08","d146"),("frus1917-72PubDipv08","d149"),("frus1977-80v30","d152")]
tot = 0
for v, d in cited:
    n = c.execute("SELECT COUNT(*) FROM external_citations WHERE volume_id=? AND document_id=?", (v, d)).fetchone()[0]
    tot += n
print("external_citations rows over the 22 cited docs:", tot)
# earliest / latest cited by document_dates
rows = c.execute("SELECT dd.volume_id, dd.document_id, dd.date_iso FROM document_dates dd WHERE (dd.volume_id||'/'||dd.document_id) IN (%s) ORDER BY dd.date_iso" % ",".join("'%s/%s'" % p for p in cited)).fetchall()
print("cited docs by date_iso:", rows[0], "...", rows[-1], "n=", len(rows))
