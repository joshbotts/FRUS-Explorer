import re, json, sqlite3, time
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s4/"
OUT = RUN + "refuter/"
con = sqlite3.connect(DB, uri=True)
con.execute("PRAGMA query_only=1")
t0 = time.time()
def log(*a):
    print(f"[{time.time()-t0:7.1f}s]", *a, flush=True)

ED2 = "('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
APP = "c.is_front_matter=0 AND c.is_editorial_note=0"
J = "frus_documents f JOIN document_cache c ON c.rowid=f.rowid"

coll = json.load(open(RUN + "collection.fruscollection"))
cited = [(e["volumeId"], e["documentId"]) for e in coll["entries"] if e["kind"] == "document"]
# the overview's cited pairs, independently
ov = open(RUN + "overview.md").read()
ovpairs = sorted(set(re.findall(r"historicaldocuments/([^/\s)]+)/(d\d+)", ov)))
log("overview cites", len(ovpairs), "distinct pairs; collection holds", len(cited), "; cited not in collection:", [p for p in ovpairs if p not in set(cited)], "; in collection not cited:", [p for p in cited if p not in set(ovpairs)])
log("collection volumes:", len({v for v, d in cited}))

# 1. canary
log("canary:", con.execute("SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache").fetchone())
# 2. denominator
den = con.execute(f"SELECT count(*) FROM document_cache c WHERE {APP} AND c.volume_id NOT IN {ED2}").fetchone()[0]
log("non-apparatus, Ed2-excluded documents:", den)
# 3. family
FAM = "corrupt OR bribe OR briberi OR kickback OR payoff OR venal OR embezzl OR malfeas OR misappropri OR nepot OR payola"
fam = set(con.execute(f"SELECT c.volume_id,c.document_id FROM {J} WHERE frus_documents MATCH ? AND {APP} AND c.volume_id NOT IN {ED2}", (FAM,)).fetchall())
log("FAMILY count (Ed2 excluded):", len(fam), " share of denominator: %.4f" % (len(fam) / den))
fam_incl = set(con.execute(f"SELECT c.volume_id,c.document_id FROM {J} WHERE frus_documents MATCH ? AND {APP}", (FAM,)).fetchall())
log("FAMILY count (Ed2 included; the vector scope):", len(fam_incl))
# 4. nexus
NX = open(RUN + "nexus.txt").read().strip()
nx = set(con.execute(f"SELECT c.volume_id,c.document_id FROM {J} WHERE frus_documents MATCH ? AND {APP} AND c.volume_id NOT IN {ED2}", (NX,)).fetchall())
log("NEXUS count:", len(nx), "| union with family (vector scope):", len(fam_incl | set(con.execute(f"SELECT c.volume_id,c.document_id FROM {J} WHERE frus_documents MATCH ? AND {APP}", (NX,)).fetchall())))
# 5. q9 / q10 counts
def cnt(m, extra=""):
    return con.execute(f"SELECT count(*) FROM {J} WHERE frus_documents MATCH ? AND {APP} {extra}", (m,)).fetchone()[0]
for label, m in [("corrupt", "corrupt"), ("department of state", '"department of state"'), ("zzz", "zzz_impossible_zzz"),
                 ("teapot dome", '"teapot dome"'), ("spoils system", '"spoils system"'), ("abscam", "abscam"), ("watergate", "watergate"),
                 ("FCPA", '"foreign corrupt practices"'), ("questionable payments", '"questionable payments"'), ("lockheed", "lockheed"),
                 ("transparency international", '"transparency international"'), ("anti corruption", '"anti corruption"')]:
    log(f"count {label}: {cnt(m)}")
q9 = set(con.execute(f"""SELECT c.volume_id,c.document_id FROM {J} WHERE frus_documents MATCH '"questionable payments" OR "foreign corrupt practices" OR (lockheed AND (bribe OR briberi OR corrupt))' AND {APP}""").fetchall())
log("q9 lockheed/FCPA set:", len(q9))
log("latest dated doc with corrupt:", con.execute(f"SELECT MAX(d.date_iso) FROM {J} JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE frus_documents MATCH 'corrupt' AND {APP}").fetchone())
# 1990s
n90 = con.execute(f"SELECT count(*) FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE {APP} AND c.volume_id NOT IN {ED2} AND d.date_iso >= '1990'").fetchone()[0]
dates = {(v, d): x for v, d, x in con.execute("select volume_id,document_id,date_iso from document_dates")}
f90 = [k for k in fam if dates.get(k) and dates[k] >= "1990"]
log("dated 1990 or later (non-apparatus, Ed2 excl):", n90, "; family hits among them:", len(f90), f90)
# 6. q5 header LIKE
q5 = set(con.execute("SELECT c.volume_id, c.document_id FROM document_cache c WHERE (c.header LIKE '%corrupt%' OR c.header LIKE '%bribe%' OR c.header LIKE '%graft%' OR c.header LIKE '%scandal%' OR c.header LIKE '%kickback%' OR c.header LIKE '%payoff%' OR c.header LIKE '%embezzl%' OR c.header LIKE '%Foreign Corrupt%' OR c.header LIKE '%questionable payments%') AND c.is_front_matter=0 AND c.is_editorial_note=0").fetchall())
log("q5 header LIKE set:", len(q5))
# 7. q6
q6 = [tuple(r[:2]) for r in con.execute(f"SELECT c.volume_id,c.document_id FROM {J} LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE frus_documents MATCH 'corrupt OR bribe OR briberi' AND c.volume_id='frus1894app2' AND {APP} ORDER BY bm25(frus_documents) LIMIT 12").fetchall()]
log("q6 (1894app2 top 12):", q6)
# 8. q7 calls
DEF = "corrupt OR bribe OR briberi OR kickback OR payoff OR embezzl OR malfeas OR nepot OR venal"
def q7(lo, hi, n, q=DEF, vol=""):
    return con.execute(f"""SELECT c.volume_id,c.document_id,substr(c.header,1,70),d.date_iso,snippet(frus_documents,6,'[[',']]',' … ',28)
FROM {J} JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
WHERE frus_documents MATCH ? AND {APP} AND d.date_iso>=? AND d.date_iso<? AND (?='' OR c.volume_id=?) AND c.volume_id NOT IN {ED2}
ORDER BY bm25(frus_documents) LIMIT ?""", (q, lo, hi, vol, vol, n)).fetchall()
calls = [
    ("q7 1943 1950 14 default", ("1943", "1950", 14)),
    ("q7 1860 1930 20 nexus", ("1860", "1930", 20, NX)),
    ("q7 1940 1950 22 nexus", ("1940", "1950", 22, NX)),
    ("q7 1950 1962 22 nexus", ("1950", "1962", 22, NX)),
    ("q7 1963 1990 30 nexus", ("1963", "1990", 30, NX)),
    ("q7 1970 1985 14 QP/FCPA/lockheed", ("1970", "1985", 14, '"questionable payments" OR "foreign corrupt practices" OR (lockheed AND (bribe OR briberi OR corrupt))')),
    ("q7 1966 1969 14 corrupt AND names", ("1966", "1969", 14, "corrupt AND (vietnam OR saigon OR thieu OR ky)")),
    ("q7 VOL=v05 1966 1969 14 corrupt", ("1966", "1969", 14, "corrupt", "frus1964-68v05")),
    ("q7 1888 1895 14 corrupt/bribe", ("1888", "1895", 14, "corrupt OR bribe OR briberi")),
    ("q7 VOL=app2 1888 1895 14 NEAR", ("1888", "1895", 14, "NEAR(corrupt queen, 30) OR NEAR(corrupt annex, 40) OR NEAR(bribe legislature, 30)", "frus1894app2")),
    ("q7 1946 1950 40 NEAR(aid/assistance/loan/military)", ("1946", "1950", 40, "NEAR(corrupt aid, 20) OR NEAR(corrupt assistance, 20) OR NEAR(corrupt loan, 20) OR NEAR(corrupt military, 12)")),
    ("q7 VOL=ve11p1 1969 1977 12", ("1969", "1977", 12, "corrupt OR bribe OR briberi", "frus1969-76ve11p1")),
    ("q7 VOL=1947v07 1947-09 1947-10 8 wedemeyer", ("1947-09", "1947-10", 8, "wedemeyer AND (corrupt OR supervision)", "frus1947v07")),
    ("q7 VOL=1958-60v01 1958 1961 12 corrupt/can lao", ("1958", "1961", 12, 'corrupt OR "can lao"', "frus1958-60v01")),
]
q7sets = {}
for name, args in calls:
    rows = q7(*args)
    if name.startswith("q7 1946 1950 40"):
        pat = re.compile(r"Secretary of State|Marshall|Acheson|Truman|Under Secretary|Department|Memorandum")
        rows = [r for r in rows if pat.search(f"{r[0]}/{r[1]} {r[3]} | {r[2]} | {re.sub(chr(10),' ',r[4])}")][:24]
    q7sets[name] = [(r[0], r[1]) for r in rows]
    log(name, "->", len(rows), "rows")
json.dump({k: v for k, v in q7sets.items()}, open(OUT + "q7_sets.json", "w"))
# 9. headings
pat = re.compile(r"corrupt|brib|graft|scandal|kickback|payoff|embezzl|malfeas|venal|nepot", re.I)
heads = []
def walk(v, n):
    t = n.get("title", "")
    if pat.search(t): heads.append((v, re.sub(r"\s+", " ", t)[:160]))
    for s in n.get("subsections", []): walk(v, s)
nv = 0
for v, j in con.execute("select volume_id, structure_json from volume_structures"):
    nv += 1
    for sct in json.loads(j).get("sections", []): walk(v, sct)
log("volume_structures scanned:", nv, "headings matching the family:", len(heads), [h for h in heads if re.search("corrupt", h[1], re.I)])

# 10. 40-sample strict/tolerant
hits = sorted(fam)
strict = re.compile(r"\b(corruption|corrupt|bribe|bribery|kickback|payoff|venal|embezzlement|nepotism|malfeasance|misappropriation|payola)\b", re.I)
toler = re.compile(r"corrupt\w*|brib\w*|kickback\w*|pay-?off\w*|venal\w*|embezzl\w*|nepot\w*|malfeas\w*|misappropriat\w*|payola", re.I)
step = len(hits) / 40
sample = [hits[int(i * step)] for i in range(40)]
s_ok = t_ok = 0
ctxs = []
for v, d in sample:
    h, dl, sn, b = con.execute("select header,coalesce(dateline,''),coalesce(source_note,''),body_text from document_cache where volume_id=? and document_id=?", (v, d)).fetchone()
    txt = re.sub(r"\s+", " ", " ".join([h, dl, sn, b]))
    ms = strict.search(txt); mt = toler.search(txt)
    s_ok += bool(ms); t_ok += bool(mt)
    m = mt or ms
    ctxs.append((f"{v}/{d}", txt[max(0, m.start() - 90):m.end() + 90] if m else ""))
log(f"40-sample: STRICT {s_ok}/40 TOLERANT {t_ok}/40")
json.dump(ctxs, open(OUT + "sample40_ctx.json", "w"), indent=0)
same_sample = sample == [tuple(x) for x in json.load(open(RUN + "work/sample40.json"))] if False else None
try:
    theirs = [(r[0], r[1]) for r in json.load(open(RUN + "work/sample40.json"))]
    log("same 40 sample as the session's:", sample == theirs)
except Exception as e:
    log("could not compare sample:", e)

# 11. membership table
print("\nREACH TABLE (cited pair | family | nexus | q9 | q5 | q6 | q7 calls that return it | heading)")
allq7 = {}
for name, pairs in q7sets.items():
    for p in pairs: allq7.setdefault(tuple(p), []).append(name)
strict_vec = []
for v, d in cited:
    k = (v, d)
    inq7 = allq7.get(k, [])
    anyq = k in fam or k in nx or k in q9 or k in q5 or k in q6 or bool(inq7)
    print(f"{v}/{d} | fam={k in fam} nx={k in nx} q9={k in q9} q5={k in q5} q6={k in q6} | q7: {inq7}")
    if not anyq: strict_vec.append(k)
print("cited documents returned by NO logged full-text/heading query:", strict_vec)
json.dump({"fam": sorted(fam), "nx": sorted(nx), "q9": sorted(q9), "q5": sorted(q5), "q6": q6}, open(OUT + "sets.json", "w"))
log("done")
