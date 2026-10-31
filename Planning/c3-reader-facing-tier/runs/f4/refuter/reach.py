#!/usr/bin/env python3
"""Refuter reach test for cell f4: is each cited document returned by a full-text or heading query the session logged?"""
import json, re, sqlite3
RUN = '/Users/jbotts/frus-analysis/c3f/runs/f4/'
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
S = json.load(open(RUN + 'scope_sets.json'))
c = sqlite3.connect(DB, uri=True)
c.execute("CREATE TEMP TABLE R(volume_id TEXT PRIMARY KEY)"); c.executemany("INSERT INTO R VALUES (?)", [(v,) for v in S['R']])
c.execute("CREATE TEMP TABLE G(volume_id TEXT PRIMARY KEY)"); c.executemany("INSERT INTO G VALUES (?)", [(v,) for v in S['G']])

cited = [("frus1950v06","d50"),("frus1964-68v01","d122"),("frus1917-72PubDipv07","d85"),("frus1969-76v38p2","d105"),("frus1924v01","d540"),("frus1949v09","d558"),("frus1952-54v12p2","d403"),("frus1917-72PubDipv07","d32"),("frus1917-72PubDipv08","d58"),("frus1917-72PubDipv08","d99"),("frus1955-57v22","d447"),("frus1961-63v23","d289"),("frus1964-68v27","d386"),("frus1964-68v02","d160"),("frus1964-68v29p2","d46"),("frus1964-68v26","d106"),("frus1917-72PubDipv08","d31"),("frus1955-57v23p2","d50"),("frus1977-80v30","d79"),("frus1917-72PubDipv08","d146"),("frus1917-72PubDipv08","d149"),("frus1977-80v30","d152")]

U = '''(USIS OR USIA OR JUSPAO OR "Information Agency" OR "Information Service" OR "psychological warfare" OR "psychological operations" OR "psychological strategy" OR "information program" OR "cultural exchange" OR "educational exchange" OR Fulbright OR "Voice of America" OR "exchange of persons" OR "hearts and minds" OR "cultural program" OR "Asia Foundation" OR "leader grant" OR "information officer" OR "cultural affairs" OR "cultural relations" OR "public diplomacy" OR "information activities")'''
U1 = U[:-1] + ' OR "propaganda")'
A = '(Vietnam OR Viet OR Korea OR Japan OR Japanese OR China OR Chinese OR Indonesia OR Philippines OR Thailand OR Laos OR Cambodia OR Asia OR Asian OR Taiwan OR Malaysia OR Singapore OR Pacific)'
A2 = '(Vietnam OR Korea OR Japan OR China OR Indonesia OR Philippines OR Thailand OR Laos OR Cambodia OR Asia OR Asian OR Taiwan OR Burma OR Malaysia OR Singapore)'
HDR = "(d.header LIKE '%Asia%' OR d.header LIKE '%Viet%' OR d.header LIKE '%Japan%' OR d.header LIKE '%China%' OR d.header LIKE '%Chinese%' OR d.header LIKE '%Korea%' OR d.header LIKE '%Indonesia%' OR d.header LIKE '%Philippines%' OR d.header LIKE '%Thai%' OR d.header LIKE '%Pacific%' OR d.header LIKE '%Taiwan%' OR d.header LIKE '%Far East%')"
BASE = "SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid {join} WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ? {extra}"

sets = {}
def load(name, sql, params, limit=None):
    rows = c.execute(sql, params).fetchall()
    if limit: rows = rows[:limit]
    sets[name] = set(rows)
    print(f"{name}: {len(sets[name])} rows")

# M04 union in R (share.py / union2.py / vecnn.py S2)
load('S2_union_in_R (M04)', BASE.format(join='JOIN R ON R.volume_id=d.volume_id', extra=''), (U,))
# union1: union + propaganda in R, bm25 top 200 (a printed list)
load('union1_top200 (bm25, printed)', BASE.format(join='JOIN R ON R.volume_id=d.volume_id', extra='ORDER BY bm25(frus_documents) LIMIT 200'), (U1,))
# gq.py S1: G Asia-word MATCH + Asia header LIKE (printed list of 61)
load('S1_G_Asia_header (M06, printed)', BASE.format(join='JOIN G ON G.volume_id=d.volume_id', extra='AND ' + HDR), (A,))
# union2.py SQLG: G Asia-word MATCH, per-volume COUNT only (never listed)
load('union2_SQLG_G_Asia_words (count only, never listed)', BASE.format(join='JOIN G ON G.volume_id=d.volume_id', extra=''), (A2,))
# union2.py SQLC rows in G would also be: the info union over G? not run. skip.
# pre.py probe (top 12 printed)
load('pre_probe_top12 (printed)', BASE.format(join='', extra='ORDER BY bm25(frus_documents) LIMIT 12'), ('("Boxer indemnity" OR "indemnity" ) AND (students OR education OR educational OR university OR scholarships) AND China',))
# pre.py count-only terms over whole corpus (never listed)
for t in ['"Boxer indemnity"', '"indemnity" AND "education"', '"remission" AND "indemnity" AND "students"', '"cultural relations"', '"Division of Cultural Relations"', '"educational exchange"', '"Voice of America"', '"public diplomacy"', '"Department of State"']:
    load(f'pre_count_only {t} (count only, never listed)', BASE.format(join='', extra=''), (t,))
# jk.py top 28
JK = '(USIS OR USIA OR "Information Agency" OR "Information Service" OR "cultural exchange" OR "educational exchange" OR Fulbright OR "Voice of America" OR "exchange of persons" OR "cultural program" OR "information program" OR CULCON OR "cultural relations")'
vols = ('frus1961-63v22','frus1964-68v29p1','frus1964-68v29p2','frus1958-60v18','frus1955-57v23p1','frus1955-57v23p2','frus1969-76v19p1','frus1969-76v19p2','frus1952-54v14p2','frus1952-54v15p1','frus1952-54v15p2')
load('jk_top28 (printed)', BASE.format(join='', extra="AND d.volume_id IN (%s) ORDER BY bm25(frus_documents) LIMIT 28" % ','.join("'%s'" % v for v in vols)), (JK,))
# beliefs1.py: each query's top-8 printed list, and the whole match set (count only)
qs = ['NEAR(Asians propaganda, 12)','NEAR(Asians psychology, 12)','"Asian mind"','"Asiatic mind"','NEAR(oriental psychology, 12)','NEAR(Asian "mentality", 10)','NEAR(Asians "respect", 10)','NEAR(Vietnamese "psychology", 10)','NEAR(Japanese "psychology", 10)','NEAR(Chinese "psychology", 10)','NEAR(Asians "weakness", 8)','NEAR(Asians "strength", 8)','NEAR("Asian" "face", 6)','"loss of face"','"save face"','"saving face"','NEAR("Asians" "impressed", 12)','"Asian peoples"','NEAR("Asians" "propaganda" "United States", 20)']
for qq in qs:
    load(f'beliefs1 top8 {qq} (printed)', BASE.format(join='JOIN R ON R.volume_id=d.volume_id', extra='ORDER BY bm25(frus_documents) LIMIT 8'), (qq,))
    load(f'beliefs1 full {qq} (count only)', BASE.format(join='JOIN R ON R.volume_id=d.volume_id', extra=''), (qq,))
# vocab1.py terms in R: count only
for t in ['"psychological warfare"','"psychological operations"','"psychological strategy"','"information program"','USIS','USIA','"United States Information Service"','"Voice of America"','"cultural exchange"','"educational exchange"','Fulbright','"Asia Foundation"','propaganda','prestige','"image of the United States"','"American image"','"hearts and minds"','"cultural program"','"leader grant"','"exchange of persons"','"binational center"','neutralism','"public diplomacy"','"information officer"','"cultural affairs"','"oriental mind"','"face"','"Department of State"','"public opinion"','"Information Agency"','"Information Service"','"psychological"','"Operations Coordinating Board"','"Psychological Strategy Board"']:
    load(f'vocab1 {t} in R (count only)', BASE.format(join='JOIN R ON R.volume_id=d.volume_id', extra=''), (t,))
# ad hoc sqlite3 queries in the log: the 1906-09 indemnity probe (printed list of 8)
load('adhoc_1906-09_indemnity_top8 (printed)', BASE.format(join='', extra="AND d.volume_id IN ('frus1907p1','frus1908','frus1907p2','frus1909','frus1906p1') ORDER BY bm25(frus_documents) LIMIT 8"), ('(indemnity OR indemnities) AND (education OR educational OR students OR university) AND China',))

printed = [k for k in sets if '(printed)' in k]
countonly = [k for k in sets if 'count only' in k]
print('\n== Membership of each cited document ==')
summary = {}
for v, d in cited:
    p = [k for k in printed if (v, d) in sets[k]]
    co = [k for k in countonly if (v, d) in sets[k]]
    summary[(v, d)] = (p, co)
    print(f"\n{v}/{d}:")
    print(f"   returned by PRINTED/LISTED queries: {len(p)} -> {p[:4]}")
    print(f"   returned by COUNT-ONLY queries: {len(co)} -> {co[:6]}")
print('\n== Strict verdict (returned by any logged full-text/heading query, printed or count-only) ==')
for (v, d), (p, co) in summary.items():
    strict = 'FTS-REACHED' if (p or co) else 'NOT RETURNED BY ANY LOGGED QUERY'
    practical = 'in a printed/listed result set' if p else 'NOT in any printed/listed result set'
    print(f"  {v}/{d}: strict={strict}; practical={practical}")
