# Refuter: REACH. For each of the 19 cited pairs, re-run every full-text (MATCH / LIKE) and heading
# query the session logged and test membership; then the two readings and V7.
import json, re, sqlite3
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s2"
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
NA_IN = "c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
NA_LIKE = "c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT LIKE '%Ed2'"
cited = [tuple(l.strip().split("/")) for l in open(RUN + "/cited.txt") if l.strip()]

# every MATCH the log records (scope1, header, p1, p2, p3, census, lockheed, p4, ff, the d204 re-run)
queries = []
def add(label, match, vols=None, like=None, filt=NA_IN): queries.append((label, match, vols, like, filt))
add("scope1 family", "corrupt OR bribe OR briberi OR graft OR kickback OR embezzl")
add("scope1 corrupt", "corrupt"); add("scope1 bribe", "bribe OR briberi"); add("scope1 graft", "graft"); add("scope1 embezzl", "embezzl"); add("scope1 kickback", "kickback")
add("scope1 POS", '"department of state"')
add("header MATCH", "header:(corrupt OR bribe OR briberi OR graft OR kickback OR embezzl)", filt="c.is_front_matter=0 AND c.is_editorial_note=0")
add("p1 china", "corrupt OR graft", ["frus1943China","frus1944v06","frus1945v07","frus1946v10","frus1947v07","frus1948v07","frus1948v08","frus1949v08","frus1949v09"], filt=NA_LIKE)
add("p1 lockheed(stem trap)", "lockhe AND (bribe OR briberi OR payment OR scandal OR corrupt)", filt=NA_LIKE)
add("p1 fcpa", '"corrupt practic" OR "question payment" OR "illicit payment" OR "improp payment"', filt=NA_LIKE)
add("p1 vietnam5860", "corrupt", ["frus1958-60v01","frus1961-63v01","frus1961-63v02","frus1961-63v03","frus1961-63v04"], filt=NA_LIKE)
add("p1 vietnam6468", "corrupt", ["frus1964-68v01","frus1964-68v02","frus1964-68v03","frus1964-68v04","frus1964-68v05","frus1964-68v06","frus1964-68v07"], filt=NA_LIKE)
add("p2 lockhe", "lockhe", filt=NA_LIKE); add("p2 lockhe payoff", "lockhe AND (payoff OR scandal)", filt=NA_LIKE)
add("p2 question payments", '"question payment" AND (compani OR firm OR corpor)', filt=NA_LIKE)
add("p2 korea", "corrupt", ["frus1958-60v18","frus1961-63v22","frus1964-68v29p1","frus1952-54v15p1"], filt=NA_LIKE)
add("p2 iran", "corrupt OR bribe OR briberi", ["frus1951-54Iran","frus1958-60v12","frus1961-63v17","frus1964-68v22"], filt=NA_LIKE)
add("p2 saudi", "bribe OR briberi", ["frus1955-57v13","frus1958-60v12","frus1958-60v13"], filt=NA_LIKE)
add("p2 centam", "corrupt", ["frus1977-80v15","frus1969-76ve11p1"], filt=NA_LIKE)
add("p2 zaire", "corrupt", ["frus1969-76ve05p1","frus1977-80v17p2","frus1964-68v23"], filt=NA_LIKE)
add("p3 full words", "corruption OR bribery OR bribe OR graft OR kickback OR embezzlement", filt=NA_LIKE)
add("p3 lockheed", "lockheed", filt=NA_LIKE)
add("p3/lockheed.py lockheed+", "lockheed AND (bribe OR bribery OR payments OR scandal OR corruption)")
add("p3 questionable|fcpa", '"questionable payments" OR "foreign corrupt practices"', filt=NA_LIKE)
add("census questionable payments", '"questionable payments"'); add("census foreign corrupt practices", '"foreign corrupt practices"')
add("census illicit payments", '"illicit payments"'); add("census corrupt practices", '"corrupt practices"')
add("p4 fcpa 1981-88", '"foreign corrupt practices"', like="frus1981-88%"); add("p4 corrupt practices 1981-88", '"corrupt practices"', like="frus1981-88%")
add("p4 corrupt|bribe 1981-88", "corrupt OR bribe OR briberi", like="frus1981-88%")
add("p4 lockheed bernhard", "lockheed AND (bernhard OR netherlands OR dutch)"); add("p4 lockheed italy", "lockheed AND (italy OR italian)")
add("p4 church+", '"church committee" AND (bribe OR bribery OR payments)'); add("p4 church", '"church committee"')
add("p4 anticorruption", '"anti corruption" OR anticorruption'); add("p4 consular bribery", "(bribe OR bribery) AND (consul OR consular) AND (fee OR fees)")
add("p4 bribe", "bribe OR bribery"); add("ff united states", '"united states"')
add("d204 re-run (all terms)", 'corrupt OR bribe OR briberi OR graft OR kickback OR embezzl OR lockheed OR "corrupt practices" OR "illicit payments" OR "questionable payments"', filt="1=1")
add("d204 control farley (pinned to the pair)", "farley", filt="c.volume_id='frus1961-63v22' AND c.document_id='d204'")

sets = {}
for label, match, vols, like, filt in queries:
    sql = f"SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {filt}"
    args = [match]
    if vols: sql += " AND c.volume_id IN (%s)" % ",".join("?" * len(vols)); args += vols
    if like: sql += " AND c.volume_id LIKE ?"; args.append(like)
    rows = set(con.execute(sql, args).fetchall())
    sets[label] = rows
    print(f"{label:40s} MATCH {match[:60]:60s} -> {len(rows)} docs")

# the chapter-heading query: which documents sit under the two headings heads.py found
print("\nheading hits (heads.py / header MATCH): frus1936v05 ch50, frus1958-60v01 ch1 — documents under them:")
def docs_under(volume, needle):
    sj = json.loads(con.execute("SELECT structure_json FROM volume_structures WHERE volume_id=?", (volume,)).fetchone()[0])
    found = []
    def walk(node, under):
        if isinstance(node, dict):
            title = node.get("title") or node.get("heading") or node.get("head") or ""
            hit = under or (needle.lower() in str(title).lower())
            for k in ("documentId", "id", "docId"):
                if hit and k in node and isinstance(node[k], str) and node[k].startswith("d"): found.append(node[k])
            for k, v in node.items():
                if isinstance(v, (dict, list)): walk(v, hit)
        elif isinstance(node, list):
            for x in node: walk(x, under)
    walk(sj, False)
    return found
sj = json.loads(con.execute("SELECT structure_json FROM volume_structures WHERE volume_id='frus1958-60v01'").fetchone()[0])
print("   structure_json sample:", json.dumps(sj)[:700])
under = docs_under("frus1958-60v01", "CAN LAO PARTY, CORRUPTION")
print("   documents under the frus1958-60v01 corruption chapter:", len(under), under[:12], "… includes d131:", "d131" in under, "d135:", "d135" in under)
heading_docs = {("frus1958-60v01", d) for d in under} | {("frus1936v05", d) for d in docs_under("frus1936v05", "embezzled motor vehicles")}

fam = set(tuple(x) for x in json.load(open(RUN + "/family_hits.json")))
print("\n=== per cited document ===")
discovery = [l for l in sets if not l.startswith("d204 control")]
strict_vec, untraced = [], []
for v, d in cited:
    hit = [l for l in discovery if (v, d) in sets[l]]
    hit_ctl = [l for l in sets if l.startswith("d204 control") and (v, d) in sets[l]]
    print(f"{v}/{d}: in family_hits.json={ (v,d) in fam }; returned by {len(hit)} discovery queries {hit[:6]}{'…' if len(hit) > 6 else ''}; heading-chapter={ (v,d) in heading_docs }; pinned control={hit_ctl}")
    if not hit and (v, d) not in heading_docs:
        strict_vec.append((v, d))
print("\nstrictly vector-reached (returned by no logged discovery query nor under a matching heading):", strict_vec)
# the quoted ones among them
ex = {(v, d) for v, d, t in json.load(open(RUN + "/excerpts.json"))}
print("…of which quoted in the overview:", [p for p in strict_vec if p in ex])
# does d204 contain any family word literally?
b = con.execute("SELECT header||' '||COALESCE(dateline,'')||' '||COALESCE(source_note,'')||' '||body_text FROM document_cache WHERE volume_id='frus1961-63v22' AND document_id='d204'").fetchone()[0]
print("d204 literal family words:", re.findall(r"\b(corrupt\w*|brib\w*|graft\w*|kick[\s\-]?backs?|embezzl\w*)\b", b, re.I), "; 'Farley' in text:", "Farley" in b)
