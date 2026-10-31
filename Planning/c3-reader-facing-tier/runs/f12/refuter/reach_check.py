# Refuter's reach check for run f12: re-run every full-text / heading query the session logged (queries.log lines 10-14, 36-37)
# and test membership of every document the overview cites, plus the 4 collection-only documents.
import re, json, sqlite3
R = "/Users/jbotts/frus-analysis/c3f/runs/f12"
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)

ov = open(R + "/overview.md").read()
cited_urls = sorted(set(re.findall(r"historicaldocuments/([^/\s)]+)/(d\d+\w*)", ov)))
print("documents cited by URL in overview:", len(cited_urls))
col = json.load(open(R + "/collection.fruscollection"))
colpairs = sorted({(e["volumeId"], e["documentId"]) for e in col["entries"] if e.get("kind") == "document"})
print("collection documents:", len(colpairs))
print("cited but not in collection:", [p for p in cited_urls if p not in colpairs])
print("in collection but not cited by URL:", [p for p in colpairs if p not in cited_urls])

SEVEN = "('frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1977-80v30','frus1961-63v25','frus1955-57v09','frus1969-76v38p2')"
AREA_IN = "('frus1950v06','frus1951v06p1','frus1951v06p2','frus1952-54v12p1','frus1952-54v12p2','frus1952-54v13p1','frus1952-54v14p2','frus1952-54v14p1','frus1955-57v21','frus1955-57v22','frus1955-57v23p1','frus1955-57v01','frus1958-60v16','frus1958-60v15','frus1958-60v18','frus1958-60v17','frus1958-60v01','frus1961-63v22','frus1961-63v23','frus1964-68v26','frus1964-68v27','frus1964-68v29p2','frus1969-76v19p2','frus1969-76v20','frus1969-76ve12','frus1977-80v22','frus1949v07p1','frus1949v07p2','frus1948v06')"
SIXTEEN = "('frus1952-54v12p1','frus1952-54v12p2','frus1955-57v21','frus1955-57v22','frus1958-60v16','frus1958-60v15','frus1955-57v23p1','frus1958-60v18','frus1961-63v22','frus1961-63v23','frus1964-68v27','frus1969-76v20','frus1969-76ve12','frus1977-80v22','frus1950v06','frus1951v06p1')"
HDR_ASIA = """header:(asia OR asian OR "far east" OR japan OR japanese OR vietnam OR vietnamese OR korea OR korean OR philippines OR indonesia OR thailand OR burma OR laos OR cambodia OR malaya OR pacific OR china OR chinese OR okinawa OR australia)"""
HDR_INFO = """header:(psychological OR propaganda OR "information agency" OR usia OR usis OR "information program" OR "public affairs" OR "information policy" OR "cultural")"""
BM25_TERMS = """"united states information agency" OR usia OR usis OR "information program" OR "psychological" OR "image of the united states" OR "american image\""""
BROAD = """(usia OR usis OR propaganda OR "psychological warfare" OR "psychological strategy" OR "psychological operations" OR "information program" OR "voice of america" OR "public affairs" OR "image of the united states" OR "cultural exchange") AND (asia OR asian OR "far east" OR japan OR japanese OR vietnam OR vietnamese OR korea OR korean OR philippines OR indonesia OR thailand OR burma OR laos OR cambodia OR malaya OR pacific OR china OR chinese)"""
SURVEY = """(survey OR poll OR "public opinion") AND (usia OR usis OR "information agency") AND (asia OR asian OR "far east" OR japan OR japanese OR vietnam OR vietnamese OR korea OR thailand OR indonesia OR philippines)"""
BASE = "SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0"

queries = {
 "L11/12 header-Asia family, 7 info volumes (SCOPE SET A, 42 hits)": (BASE + f" AND d.volume_id IN {SEVEN}", HDR_ASIA),
 "L13 header-information family, area volumes (SCOPE SET B, 55 hits)": (BASE + f" AND (d.volume_id IN {AREA_IN} OR d.volume_id LIKE 'frus1961-63v0%' OR d.volume_id LIKE 'frus1964-68v0%')", HDR_INFO),
 "L14 bm25 top-30 over 16 regional volumes (SCOPE SET C)": ("SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN " + SIXTEEN + " AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY bm25(frus_documents) LIMIT 30", BM25_TERMS),
 "L10 broad info x Asia MATCH, corpus-wide (session saw volume counts only; here expanded to documents)": (BASE, BROAD),
 "L36/37 survey MATCH, corpus-wide (session saw volume counts and a total only)": (BASE, SURVEY),
}
results = {}
for name, (sql, match) in queries.items():
    rows = set(con.execute(sql, (match,)).fetchall())
    results[name] = rows
    print(f"\n{name}: {len(rows)} documents")

targets = sorted(set(cited_urls) | set(colpairs))
print("\n=== MEMBERSHIP (C = cited by URL in overview; K = in collection) ===")
hdr = ["pair", "C", "K"] + [f"Q{i+1}" for i in range(len(queries))]
print("\t".join(hdr))
listing = {}
for p in targets:
    flags = [("C" if p in cited_urls else "-"), ("K" if p in colpairs else "-")]
    hits = []
    for i, name in enumerate(queries):
        inq = p in results[name]
        hits.append("Y" if inq else ".")
        if inq: listing.setdefault(p, []).append(f"Q{i+1}")
    print("\t".join([f"{p[0]}/{p[1]}"] + flags + hits))
print("\nQ legend:")
for i, name in enumerate(queries): print(f"  Q{i+1} = {name}")

# strictly: a cited document returned by none of the DOCUMENT-LISTING queries the session logged (Q1-Q3). Q4 and Q5 were run only as volume counts.
print("\n=== STRICT reach over the document-listing queries Q1-Q3 ===")
for p in targets:
    doc_listing = [q for q in listing.get(p, []) if q in ("Q1", "Q2", "Q3")]
    agg_only = [q for q in listing.get(p, []) if q in ("Q4", "Q5")]
    tag = "FTS-REACHED" if doc_listing else "NOT RETURNED BY ANY DOCUMENT-LISTING QUERY"
    print(f"{p[0]}/{p[1]}: {tag}; listing queries {doc_listing}; matched by aggregate-only queries {agg_only}")

# the memo's M-2 step 4 and 5 and M-6 counts, re-derived
print("\n=== COUNTS ===")
print("1,582 non-apparatus docs in the seven volumes ->", con.execute(f"SELECT COUNT(*) FROM document_cache WHERE volume_id IN {SEVEN} AND is_front_matter=0 AND is_editorial_note=0").fetchone()[0])
print("42 header hits (Q1) ->", len(results[list(queries)[0]]))
print("55 header hits (Q2) ->", len(results[list(queries)[1]]))
q2 = results[list(queries)[1]]
viet = [p for p in q2 if re.match(r"frus1961-63v0[1-4]$|frus1964-68v0[1-7]$|frus1955-57v01$|frus1958-60v01$|frus1952-54v13p[12]$", p[0])]
print("Vietnam-volume rows among the 55 ->", len(viet), " of which frus1961-63v01-v04 ->", len([p for p in viet if re.match(r"frus1961-63v0[1-4]$", p[0])]))
for v in ["frus1961-63v01","frus1961-63v02","frus1961-63v03","frus1961-63v04"]:
    print("   ", v, len([p for p in q2 if p[0]==v]))
print("320 survey docs (Q5) ->", len(results[list(queries)[4]]))
print("zzzimpossiblezzz ->", con.execute(BASE.replace(" AND d.is_front_matter=0 AND d.is_editorial_note=0",""), ("zzzimpossiblezzz",)).fetchall())
print("non-apparatus rows in the 42 set that are South/Near East (memo says 9):")
nine = {("frus1955-57v09","d131"),("frus1917-72PubDipv07","d74"),("frus1917-72PubDipv08","d74"),("frus1917-72PubDipv08","d87"),("frus1917-72PubDipv08","d106"),("frus1917-72PubDipv08","d155"),("frus1977-80v30","d15"),("frus1977-80v30","d74"),("frus1977-80v30","d170")}
q1 = results[list(queries)[0]]
print("   the 9 named all in the 42:", nine <= q1, "; 42 minus 9 =", len(q1 - nine))
scope33 = {tuple(l.split()) for l in open(R + "/scope_set_info_volumes.txt") if l.strip()}
print("   scope_set_info_volumes.txt has", len(scope33), "pairs; equals 42 minus 9:", scope33 == (q1 - nine))
