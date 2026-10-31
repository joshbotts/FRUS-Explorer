import sqlite3, json, re, collections
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f11/"
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
sf = json.load(open(R + "series-facts-index.json")); H = sf["headings"]; ST = sf.get("statuses")
print("series-facts legend:", sf.get("legend"))
def fact(naid):
    v = sf["byNaId"].get(str(naid))
    if not v: return None
    return {"creator": H[v["c"]] if "c" in v else None, "title": v.get("t"), "extent": v.get("x"), "years": (v.get("y0"), v.get("y1")), "access": ST[v["as"]] if ST and "as" in v else v.get("as"), "raw": v}
print("\n== NAIDs named in the bottom line, in series-facts-index.json ==")
for naid, claim in [("40967285", "103 linear feet, 1956-1972, partly restricted, Exec Secretariat director's subject files"), ("1257679", "47 linear feet, 1953-1971, partly restricted, Office of Policy and Plans subject files"), ("2839192", "26 linear feet, 1947-1979, partly restricted, Exec Sec records on NSC policy papers"), ("2839191", "1953-1961, partly restricted, subject and special files"), ("2838992", "1948-1961, partly restricted, Policy Planning Council NSC work"), ("1254251", "9 linear feet, 1954-1958, partly restricted, Office of Research and Intelligence production division")]:
    print(naid, "| claim:", claim, "\n   facts:", fact(naid))
cf = json.load(open(R + "central-files-index.json"))
lots = cf["lotFiles"]
print("\n== central-files-index lotFiles rows for those NAIDs ==")
for r in lots:
    if str(r.get("naId")) in ("2839192", "2839191", "2838992", "40967285", "1257679", "1254251"):
        print(" ", {k: r[k] for k in r if k in ("lotNumber", "recordGroup", "naId", "title", "hmsMlrEntryNumbers", "dateRange", "yearStart", "yearEnd")})
print("lotFiles keys sample:", list(lots[0].keys()))
# entries in bundled JSON
import glob
print("\n== entry numbers A1-42 / UD WW 257 / P-207 / P-104 / 72A5121 in bundled JSON ==")
pats = {"A1-42": r"A1[\s\-–]?42\b", "UD WW 257": r"UD[\s\-]?WW[\s\-]?257", "P-207": r"\bP[\s\-–]?207\b", "P-104": r"\bP[\s\-–]?104\b", "72A5121": r"72[\s]?A[\s]?5121"}
for f in sorted(glob.glob(R + "*.json")):
    s = open(f, errors="replace").read()
    for k, p in pats.items():
        ms = list(re.finditer(p, s))
        if ms:
            m = ms[0]; print("  %s: %s x%d ...%s..." % (f.split('/')[-1], k, len(ms), s[max(0, m.start() - 120):m.end() + 80].replace("\n", " ")))
acc = json.load(open(R + "accession-series-index.json"))
box = acc.get("byAccession") or acc
for k in ["306/72A5121", "306/69A3445", "306/68A4933"]:
    v = box.get(k) if isinstance(box, dict) else None
    print("  accession-series-index", k, "->", (json.dumps(v)[:300] if v is not None else "absent"))
# entries in document_sources raw_text of set A and the quoted docs
print("\n== entries in document_sources.raw_text / source_note of the PD documents cited ==")
for v, d in [("frus1917-72PubDipv08", "d88"), ("frus1917-72PubDipv08", "d149"), ("frus1917-72PubDipv08", "d31"), ("frus1917-72PubDipv08", "d24"), ("frus1917-72PubDipv07", "d32"), ("frus1917-72PubDipv07", "d73"), ("frus1917-72PubDipv07", "d100"), ("frus1917-72PubDipv06", "d135"), ("frus1977-80v30", "d79"), ("frus1977-80v30", "d152"), ("frus1969-76v38p2", "d105"), ("frus1917-72PubDipv06", "d111")]:
    r = db.execute("select repository,record_group,series_name,raw_text from document_sources where volume_id=? and document_id=?", (v, d)).fetchone()
    print("  %s/%s: %s" % (v, d, r))
# set A entries overall
PDV = ['frus1917-72PubDipv06', 'frus1917-72PubDipv07', 'frus1917-72PubDipv08', 'frus1969-76v38p2', 'frus1977-80v30', 'frus1955-57v09', 'frus1961-63v25']
Q = 'header:(Asia OR Asian OR "Far East" OR Vietnam OR Vietnamese OR Japan OR Japanese OR Korea OR Korean OR Indonesia OR Philippines OR Thailand OR China OR Chinese OR Taiwan OR Pacific OR Laos OR Cambodia OR Burma OR Malaysia OR Singapore OR Australia)'
setA = db.execute("SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND d.is_front_matter=0 AND d.is_editorial_note=0" % ",".join("?" * 7), [Q] + PDV).fetchall()
ent = collections.Counter()
for v, d in setA:
    r = db.execute("select record_group,raw_text from document_sources where volume_id=? and document_id=?", (v, d)).fetchone()
    if r and r[0] == '306':
        for k, p in pats.items():
            if re.search(p, r[1]): ent[k] += 1
        if re.search(r"UD WW 193", r[1]): ent["UD WW 193"] += 1
print("  set A RG 306 rows naming each entry:", dict(ent))
# RG 306 and RG 305 raw text examples
for rgn in ("306", "305"):
    r = db.execute("select volume_id,document_id,raw_text from document_sources where record_group=? and volume_id like 'frus1917-72PubDip%' limit 2", (rgn,)).fetchall()
    print("  RG %s example rows:" % rgn, r)
r = db.execute("select volume_id,document_id,raw_text from document_sources where record_group='305' limit 3").fetchall()
print("  any RG 305 rows:", r)
# presidential library collections in external_citations of set B
vols = [l.strip() for l in open(RUN + "scope_vols.txt") if l.strip()]
REG = [v for v in vols if v not in PDV]
FAM = '(USIA OR USIS OR "Voice of America" OR "information program" OR "psychological warfare" OR "psychological strategy" OR "United States Information")'
setB = db.execute("SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND d.is_front_matter=0 AND d.is_editorial_note=0" % ",".join("?" * len(REG)), [FAM] + REG).fetchall()
libs = collections.Counter(); lotn = collections.Counter(); lotdocs = collections.defaultdict(set)
for v, d in setB:
    for r in db.execute("select repository,collection,anchor,lot_file_norm from external_citations where volume_id=? and document_id=?", (v, d)):
        if r[2] == 'presidentialLibrary': libs[(r[0], r[1])] += 1
        if r[3]: lotn[r[3]] += 1; lotdocs[r[3]].add((v, d))
print("\n== set B pointed-at presidential library collections ==", libs.most_common(6))
print("== set B pointed-at lots by documents (top 6) ==", sorted(((len(s), l) for l, s in lotdocs.items()), reverse=True)[:6])
cfl = {r["lotNumber"]: r for r in lots}
for l in ["66D95", "62D430", "63D351", "62D1"]:
    r = cfl.get(l); print("  lot", l, "->", (r["recordGroup"], r["naId"], r["title"][:70]) if r else "NOT IN INDEX")
# presidential-library-catalog: do the named collections exist?
pl = json.load(open(R + "presidential-library-catalog.json"))
s = json.dumps(pl)
for name in ["National Security File", "National Security Files", "NSC Files", "Marks Papers"]:
    print("  presidential-library-catalog mentions %r: %d" % (name, s.count(name)))
print("  presidential-library-catalog top keys:", list(pl.keys())[:10] if isinstance(pl, dict) else type(pl))
