import sqlite3, json, re, collections
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f11/"
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
vols = [l.strip() for l in open(RUN + "scope_vols.txt") if l.strip()]
PDV = ['frus1917-72PubDipv06', 'frus1917-72PubDipv07', 'frus1917-72PubDipv08', 'frus1969-76v38p2', 'frus1977-80v30', 'frus1955-57v09', 'frus1961-63v25']
REG = [v for v in vols if v not in PDV]
print("scope_vols.txt lines:", len(vols), "REG:", len(REG), "PD:", len([v for v in vols if v in PDV]))
indb = {r[0] for r in db.execute("select distinct volume_id from document_cache")}
print("scope volumes not in index:", [v for v in vols if v not in indb])
print("553 volumes in index:", len(indb), "| total rows / fm / en:", db.execute("select count(*),sum(is_front_matter),sum(is_editorial_note) from document_cache").fetchone())
ph = lambda L: ",".join("?" * len(L))
BASE = "d.is_front_matter=0 AND d.is_editorial_note=0"
def cnt(match, V):
    return db.execute("SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND %s" % (ph(V), BASE), [match] + V).fetchone()[0]
n2 = db.execute("select count(*) from document_cache d where volume_id in (%s) and %s" % (ph(REG), BASE), REG).fetchone()[0]
print("N2 REG non-apparatus docs (overview 30,092):", n2)
n4 = db.execute("select count(*) from document_cache d where volume_id in (%s) and %s" % (ph(PDV), BASE), PDV).fetchone()[0]
print("N4 PD non-apparatus docs (overview 1,582):", n4)
FAM = '(USIA OR USIS OR "Voice of America" OR "information program" OR "psychological warfare" OR "psychological strategy" OR "United States Information")'
print("N3 family A in REG (overview 1,176):", cnt(FAM, REG))
for label, m in [("soft power (0)", '"soft power"'), ("NEAR soft power 3 (0)", 'NEAR(soft power, 3)'), ("public diplomacy (2)", '"public diplomacy"'), ("cultural diplomacy (0)", '"cultural diplomacy"'), ("Radio Free Asia (0)", '"Radio Free Asia"'), ("Department of State (13,470)", '"Department of State"'), ("ZZZ_IMPOSSIBLE_ZZZ (0)", 'ZZZ_IMPOSSIBLE_ZZZ'), ("soft AND power (127)", 'soft AND power'), ("Asia Foundation (12)", '"Asia Foundation"'), ("Peace Corps (59)", '"Peace Corps"'), ("cultural exchange (92)", '"cultural exchange"'), ("educational exchange (54)", '"educational exchange"'), ("Fulbright (278)", 'Fulbright')]:
    print("  REG %-30s -> %d" % (label, cnt(m, REG)))
# soft power corpus-wide incl. front matter
print("corpus-wide 'soft power' any row:", db.execute("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH '\"soft power\"'").fetchone()[0])
# header query, 42
Q = 'header:(Asia OR Asian OR "Far East" OR Vietnam OR Vietnamese OR Japan OR Japanese OR Korea OR Korean OR Indonesia OR Philippines OR Thailand OR China OR Chinese OR Taiwan OR Pacific OR Laos OR Cambodia OR Burma OR Malaysia OR Singapore OR Australia)'
setA = db.execute("SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND %s" % (ph(PDV), BASE), [Q] + PDV).fetchall()
print("N5 header-matched docs in the 7 PD volumes (overview 42):", len(setA))
rg = collections.Counter(); repo = collections.Counter(); norow = 0
for v, d in setA:
    r = db.execute("select record_group,repository from document_sources where volume_id=? and document_id=?", (v, d)).fetchone()
    if r is None: norow += 1; continue
    rg[r[0]] += 1; repo[r[1]] += 1
print("  record_group counts (overview 27 RG 306):", dict(rg), "| repositories:", dict(repo), "| no row:", norow)
# RG 306 AND repository National Archives?
n306na = sum(1 for v, d in setA if (lambda r: r and r[0] == '306' and r[1] == 'National Archives')(db.execute("select record_group,repository from document_sources where volume_id=? and document_id=?", (v, d)).fetchone()))
print("  RG 306 with repository 'National Archives':", n306na)
# set B pointed-at 322 of 1,176, 551 rows
setB = db.execute("SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND %s" % (ph(REG), BASE), [FAM] + REG).fetchall()
docs = set(); rows = 0; anchors = collections.Counter(); libs = collections.Counter()
for v, d in setB:
    for r in db.execute("select repository,collection,anchor from external_citations where volume_id=? and document_id=?", (v, d)):
        rows += 1; docs.add((v, d)); anchors[r[2]] += 1
        if r[2] == 'presidentialLibrary': libs[(r[0], r[1])] += 1
print("set B docs with >=1 external_citations row (overview 322):", len(docs), "of", len(setB), "rows", rows, "anchors", dict(anchors))
print("  presidential library collections (36/25/18):", libs.most_common(5))
# decade shape
dec_tot = collections.Counter(); dec_hit = collections.Counter()
for v, dn, dt in db.execute("select d.volume_id,d.document_id,dd.date_iso from document_cache d left join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where d.volume_id in (%s) and %s" % (ph(REG), BASE), REG):
    if dt: dec_tot[dt[:3] + "0s"] += 1
for v, dn, dt in db.execute("SELECT d.volume_id,d.document_id,dd.date_iso FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND %s" % (ph(REG), BASE), [FAM] + REG):
    if dt: dec_hit[dt[:3] + "0s"] += 1
print("decade per 1,000 (overview 53/33/19):", {k: (dec_hit[k], dec_tot[k], round(1000 * dec_hit[k] / dec_tot[k])) for k in sorted(dec_tot)})
# false friends
other = [r[0] for r in db.execute("select distinct volume_id from document_cache where (volume_id glob 'frus194[89]*' or volume_id glob 'frus195*' or volume_id glob 'frus196*' or volume_id glob 'frus197*') and volume_id not like '%Ed2'")]
CTRL = [v for v in other if v not in vols]
ctot = db.execute("select count(*) from document_cache d where volume_id in (%s) and %s" % (ph(CTRL), BASE), CTRL).fetchone()[0]
print("control volumes:", len(CTRL), "docs", ctot)
for term in ["audience OR audiences", "USIS OR USIA"]:
    a = cnt(term, REG); c = cnt(term, CTRL)
    print("  false-friend %-22s REG %d (%.1f/1000) control %d (%.1f/1000)" % (term, a, 1000 * a / n2, c, 1000 * c / ctot))
# phrase shares
SEP = r"[\s\-,.()]+"
def tol(words): return re.compile(r"\b" + SEP.join(re.escape(w) + r"\w{0,4}" for w in words), re.I)
def strict(words): return re.compile(r"\b" + r"\s".join(re.escape(w) for w in words) + r"\b", re.I)
for name, m, words in [("information program", '"information program"', ["information", "program"]), ("psychological warfare", '"psychological warfare"', ["psychological", "warfare"]), ("psychological strategy", '"psychological strategy"', ["psychological", "strategy"])]:
    hits = db.execute("SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND %s" % (ph(REG), BASE), [m] + REG).fetchall()
    s_ok = t_ok = 0
    for v, d in hits:
        txt = re.sub(r"\s+", " ", db.execute("select header||' '||coalesce(dateline,'')||' '||coalesce(source_note,'')||' '||body_text from document_cache where volume_id=? and document_id=?", (v, d)).fetchone()[0])
        if strict(words).search(txt): s_ok += 1
        if tol(words).search(txt): t_ok += 1
    print("  share %-24s hits %d strict %d tolerant %d" % (name, len(hits), s_ok, t_ok))
# series before 1940
sf = json.load(open(R + "series-facts-index.json"))["byNaId"]
pre = sum(1 for v in sf.values() if v.get("y0") and v["y0"] < 1940)
print("series-facts: %d series, start before 1940: %d (one in %.1f)" % (len(sf), pre, len(sf) / pre))
# collection count and date span
c = json.load(open(RUN + "collection.fruscollection"))
pairs = [(e["volumeId"], e["documentId"]) for e in c["entries"] if e["kind"] == "document"]
dates = [db.execute("select date_iso from document_dates where volume_id=? and document_id=?", k).fetchone() for k in pairs]
dates = [x[0] for x in dates if x and x[0]]
print("collection documents:", len(pairs), "date span:", min(dates), "to", max(dates))
# documents quoted in the overview (distinct pairs with a quotation)
ov = open(RUN + "overview.md").read()
url_re = re.compile(r"https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)")
quotes = [m.end() for m in re.finditer(r"“([^”]+)”", ov)]
urls = [(m.start(), m.group(1), m.group(2)) for m in url_re.finditer(ov)]
qp = set()
for e in quotes:
    nxt = [u for u in urls if u[0] >= e]; qp.add((nxt[0][1], nxt[0][2]))
print("distinct documents quoted (with quotation marks) in the overview:", len(qp))
print("distinct documents cited by URL in the overview:", len({(u[1], u[2]) for u in urls}), "; in collection:", len({(u[1], u[2]) for u in urls} & set(pairs)))
# scope dates: date span of REG + PD documents
r = db.execute("select min(dd.date_iso),max(dd.date_iso) from document_dates dd join document_cache d on d.volume_id=dd.volume_id and d.document_id=dd.document_id where d.volume_id in (%s) and %s and dd.date_iso is not null" % (ph(vols), BASE), vols).fetchone()
print("scope (76 volumes) non-apparatus document date span:", r)
# manifest titles for the 69
m = {v["filename"][:-4]: re.sub(r"\s+", " ", v["title"]) for v in json.load(open(R + "manifest.json"))}
bad = [v for v in REG if not re.search(r"China|Japan|Korea|Vietnam|Indochina|Southeast Asia|East Asia|Northeast Asia|Pacific|Indonesia|Philippines|Laos|Cambodia|Asia|Malaysia|Taiwan", m.get(v, ""), re.I)]
print("REG volumes whose manifest title fails the inclusion regex:", bad)
print("REG volumes with Ed2/Supp or South Asia/Near East names:", [v for v in REG if "Ed2" in v or "Supp" in v or re.search(r"South Asia|Near East", m.get(v, ""))])
