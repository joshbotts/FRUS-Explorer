import sqlite3, json, re
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f11/"
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rd = lambda f: [l.strip() for l in open(RUN + f) if l.strip()]
vols = rd("scope_vols.txt"); early = rd("scope_early.txt"); japan = rd("scope_japan.txt"); core = rd("eap_core.txt")
PDV = ['frus1917-72PubDipv06', 'frus1917-72PubDipv07', 'frus1917-72PubDipv08', 'frus1969-76v38p2', 'frus1977-80v30', 'frus1955-57v09', 'frus1961-63v25']
REG = [v for v in vols if v not in PDV]
BASE = "d.is_front_matter=0 AND d.is_editorial_note=0"
ph = lambda L: ",".join("?" * len(L))
def matches(q, v, d):
    return db.execute("SELECT 1 FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id=? AND d.document_id=?", (q, v, d)).fetchone() is not None
def ranked(q, V, limit):
    rows = db.execute("SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND %s ORDER BY bm25(frus_documents)" % (ph(V), BASE), [q] + V).fetchall()
    return rows, limit
FAM = '(USIA OR USIS OR "Voice of America" OR "information program" OR "psychological warfare" OR "psychological strategy" OR "United States Information")'
HDR = 'header:(Asia OR Asian OR "Far East" OR Vietnam OR Vietnamese OR Japan OR Japanese OR Korea OR Korean OR Indonesia OR Philippines OR Thailand OR China OR Chinese OR Taiwan OR Pacific OR Laos OR Cambodia OR Burma OR Malaysia OR Singapore OR Australia)'
DENS = '("psychological warfare" OR "psychological strategy" OR USIA OR USIS OR "Voice of America" OR "cultural exchange" OR "information program" OR propaganda OR "Asian opinion" OR "hearts and minds" OR "United States Information")'
QA = 'NEAR(psychological Asia, 15) OR NEAR(propaganda Asian, 10) OR NEAR(USIS Asian, 15) OR NEAR(information Asian audience, 10)'
QB = '(psychological OR propaganda OR "information program" OR USIS OR "Voice of America") AND (Asian OR Asians OR Asia) AND (opinion OR attitudes OR reaction OR neutralism)'
QD = '(USIS OR USIA OR "cultural exchange" OR "educational exchange" OR Fulbright OR "cultural program" OR "information program" OR "image") AND ("anti-American" OR neutralism OR intellectuals OR students OR Zengakuren OR "public opinion")'
INIT = ['"soft power"', '"psychological warfare"', '"psychological strategy"', 'USIA', 'USIS', '"Voice of America"', '"cultural exchange"', '"image of the United States"', '"hearts and minds"', 'propaganda', '"information program"', '"Asian opinion"', 'prestige']
rA, lA = ranked(QA, vols, 25)
rB, lB = ranked(QB, early, 20)
rBv, _ = ranked(QB, vols, 0)
rD, lD = ranked(QD, japan, 18)
print("QA total over scope_vols:", len(rA), "| QB total over scope_early:", len(rB), "| QB over scope_vols:", len(rBv), "| QD over scope_japan:", len(rD))
def rank(rows, k):
    return rows.index(k) + 1 if k in rows else None
c = json.load(open(RUN + "collection.fruscollection"))
pairs = [(e["volumeId"], e["documentId"]) for e in c["entries"] if e["kind"] == "document"]
print("\n%-28s famA hdr dens | QA(rank/25) QB-early(rank/20) QB-vols(rank) QD-japan(rank/18) | init-count terms matched" % "pair")
for k in pairs:
    v, d = k
    fa = matches(FAM, v, d) and v in REG
    hd = matches(HDR, v, d) and v in PDV
    de = matches(DENS, v, d) and v in core
    init = [t for t in INIT if matches(t, v, d)]
    print("%-28s %-4s %-3s %-4s | %-11s %-16s %-13s %-17s | %s" % (v + "/" + d, fa, hd, de, rank(rA, k), rank(rB, k), rank(rBv, k), rank(rD, k), ",".join(init)))
    row = db.execute("select is_front_matter,is_editorial_note from document_cache where volume_id=? and document_id=?", k).fetchone()
    if row != (0, 0): print("   !! apparatus flags", row)
# print the top-N lists as the session saw them (ids only)
print("\nQA top 25 over scope_vols:", rA[:25])
print("QB top 20 over scope_early:", rB[:20])
print("QD top 18 over scope_japan:", rD[:18])
