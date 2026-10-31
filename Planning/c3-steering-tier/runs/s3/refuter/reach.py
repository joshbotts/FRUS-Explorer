"""Refuter step 7: for each cited pair, which logged full-text / heading query returns it, and which printed result set held it."""
import json, re, sqlite3
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s3/"
con = sqlite3.connect("file:" + DB + "?mode=ro", uri=True)
q = lambda sql, *a: con.execute(sql, a).fetchall()
cited = [tuple(l.strip().split("/")) for l in open(RUN + "cited.txt") if l.strip()]

# the logged full-text and heading queries, each as a membership test on the exact pair
Q = {
 "family MATCH (M4/M5 scope set)": "corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl",
 "family MATCH without grafter (top_bm25 / header runs)": "corrupt* OR bribe OR briberi OR graft OR kickback OR embezzl",
 "header: query": "header:(corrupt* OR bribe OR briberi OR graft OR kickback OR embezzl OR lockhe)",
 "payments phrase MATCH (M7, logged after the neighbour list)": '"improper payment" OR "illicit payment" OR "questionable payment"',
 "d155 targeted plural phrases (logged after the neighbour list)": '"improper payments" OR "illicit payments"',
 "control \"Department of State\"": '"Department of State"',
 "foreign corrupt practic* (M17)": '"foreign corrupt practic*"',
 "oecd AND (bribe OR briberi) (M17)": "oecd AND (bribe OR briberi)",
 "anti corrupt* (M18)": '"anti corrupt*"',
 "church subcommittee/committee (M19)": '"church subcommittee" OR "church committee"',
}
# printed / saved result sets, in log order
top80 = [tuple(l.split("|")[:2]) for l in open(RUN + "top_bm25.txt") if "|" in l]
hh = [tuple(l.split("|")[:2]) for l in open(RUN + "header_hits.txt") if "|" in l]
share = [(r[0], r[1]) for r in json.load(open(RUN + "share_sample.json"))["sample"]]
pay = [tuple(l.split()[:2]) for l in open(RUN + "payments.txt") if l.startswith("frus")]
vo = json.load(open(RUN + "vectors_out.json"))["neighbours"]
neigh = {a: [tuple(r[1]) for r in rows] for a, rows in vo.items()}

print("top_bm25 rows", len(top80), "| header hits", len(hh), "| share sample", len(share), "| payments census", len(pay))
for v, d in cited:
    hits = []
    for name, m in Q.items():
        n = q("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH ? AND volume_id=? AND document_id=?", m, v, d)[0][0]
        if n: hits.append(name)
    sets = []
    if (v, d) in top80: sets.append("top_bm25 #%d" % (top80.index((v, d)) + 1))
    if (v, d) in hh: sets.append("header_hits")
    if (v, d) in share: sets.append("share_sample")
    if (v, d) in pay: sets.append("payments census (after vectors)")
    via = [a for a, l in neigh.items() if (v, d) in l]
    anchor = "%s/%s" % (v, d) in neigh
    print("%s/%s" % (v, d), "\n   returned by:", hits, "\n   printed sets:", sets, "| anchor:", anchor, "| in neighbour lists of:", via)
fam = set(q("""SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
 WHERE frus_documents MATCH 'corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"""))
print("\ncited in the 3,057 scope set:", sum(1 for p in cited if p in fam), "of", len(cited), "| not in it:", [p for p in cited if p not in fam])
# the memo's M19, M16/M17/M18 figures, re-run
print("\nM19 withheld:", q("""SELECT COUNT(*), SUM(c.body_text LIKE '%not declassified%') FROM (SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
 WHERE frus_documents MATCH 'corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')) h
 JOIN document_dates t ON t.volume_id=h.volume_id AND t.document_id=h.document_id JOIN document_cache c ON c.volume_id=h.volume_id AND c.document_id=h.document_id WHERE t.date_iso >= '1969-01-20'"""))
print("M17 FCPA docs, volumes:", q("SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM frus_documents WHERE frus_documents MATCH '\"foreign corrupt practic*\"'"))
print("M18 klepto vocab:", q("SELECT term, doc FROM frus_documents_vocab WHERE term LIKE 'klepto%'"), "| anti corrupt* docs:", q("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH '\"anti corrupt*\"'"))
print("M9 control volumes with 'Department of State':", q("SELECT COUNT(*) FROM (SELECT volume_id FROM frus_documents WHERE frus_documents MATCH '\"Department of State\"' GROUP BY volume_id)"), "missing:", q("SELECT DISTINCT volume_id FROM document_cache WHERE volume_id NOT IN (SELECT volume_id FROM frus_documents WHERE frus_documents MATCH '\"Department of State\"')"), "| impossible:", q("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ'"))
print("M8 1930s / 1960s / 1970s / 1980s / 1990s:", q("""SELECT substr(t.date_iso,1,3)||'0s' dec, COUNT(*), SUM(h.document_id IS NOT NULL) FROM document_cache c JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id
 LEFT JOIN (SELECT volume_id, document_id FROM frus_documents WHERE frus_documents MATCH 'corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl') h ON h.volume_id=c.volume_id AND h.document_id=c.document_id
 WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND t.date_iso IS NOT NULL AND substr(t.date_iso,1,3) IN ('193','196','197','198','199') GROUP BY 1"""))
