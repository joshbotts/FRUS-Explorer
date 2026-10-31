"""Strict reach: for each cited pair, which logged full-text queries return it.
Saved result sets (rank_*.tsv, topic_set.tsv, survey listing) are tested by file membership;
the two printed-only rank calls (log lines 18 and 20) and the 511.00 query are re-run."""
import sqlite3, re
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f8/"
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c = sqlite3.connect(DB, uri=True)
cited = [l.strip() for l in open(RUN + "final_cited.txt") if l.strip()]

def tsv_pairs(name):
    out = []
    for l in open(RUN + name):
        p = l.rstrip("\n").split("\t")
        if len(p) >= 2 and p[0].startswith("frus"):
            out.append(p[0] + "/" + p[1])
    return out

sets = {}
sets["L7 rank_ea_info (80)"] = tsv_pairs("rank_ea_info.tsv")
sets["L8 rank_them (50, 8 vols)"] = tsv_pairs("rank_them.tsv")
sets["L11 rank_race (30)"] = tsv_pairs("rank_race.tsv")
sets["L15 rank_jp (30)"] = tsv_pairs("rank_jp.tsv")
sets["L34 rank_pubdip (40)"] = tsv_pairs("rank_pubdip.tsv")
sets["L24 topic_set (701)"] = tsv_pairs("topic_set.tsv")
surv = []
for l in open(RUN + "survey_scan.txt"):
    m = re.match(r"\s+\('([^']+)', '([^']+)'", l)
    if m: surv.append(m.group(1) + "/" + m.group(2))
sets["L46 survey AND listing (27)"] = surv

def vols(name):
    return [l.strip() for l in open(RUN + name) if l.strip()]
def rank(volfile, q, lim):
    vl = ",".join("'%s'" % v for v in vols(volfile))
    sql = f"""SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid
    WHERE frus_documents MATCH ? AND dc.volume_id IN ({vl}) AND dc.is_front_matter=0 AND dc.is_editorial_note=0
    ORDER BY bm25(frus_documents) ASC LIMIT {lim}"""
    return [a + "/" + b for a, b in c.execute(sql, (q,))]

# L18: thematic (then 8 vols: thematic_vols.txt minus PubDip) grep frus1977-80v30
eight = [v for v in vols("thematic_vols.txt") if "PubDip" not in v]
open("/Users/jbotts/frus-analysis/c3f/runs/f8/refuter/thematic8.txt", "w").write("\n".join(eight) + "\n")
q18 = '(Japan OR Japanese OR China OR Chinese OR Korea OR Indonesia OR Philippines OR Thailand OR ASEAN OR "East Asia") AND (USICA OR USIA OR "public diplomacy" OR "International Communication Agency")'
r18 = rank("refuter/thematic8.txt", q18, 25)
sets["L18 rank thematic8 (25) [re-run]"] = r18
print("L18 re-run, the frus1977-80v30 rows:", [p for p in r18 if p.startswith("frus1977-80v30")])
q20 = '(USIS OR USIA OR psychological OR "information program" OR prestige OR image) AND (Asian OR Asians)'
r20 = rank("regional_vols.txt", q20, 15)
sets["L20 rank regional4 (15) [re-run]"] = r20
print("L20 re-run:", r20)
q13 = '"511.00/8-2352" OR ("circular telegram 208") OR "Depcirtel 208"'
r13 = [a + "/" + b for a, b in c.execute("SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH ? AND dc.is_front_matter=0 AND dc.is_editorial_note=0", (q13,))]
sets["L13 511.00/8-2352 query [re-run]"] = r13
print("L13 re-run:", r13)
# also re-run rank_them with the 8-volume list to confirm the saved file is that run
r8 = rank("refuter/thematic8.txt", '("Far East" OR Asia OR Asian OR Asians OR Japan OR Japanese OR Philippines OR Indonesia OR Korea OR Vietnam OR "East Asia" OR Pacific) AND (USIA OR USIS OR "information program" OR psychological OR propaganda OR "public diplomacy" OR "exchange")', 50)
print("rank_them.tsv equals re-run over the 8 volumes:", r8 == sets["L8 rank_them (50, 8 vols)"])

# fts_scan count terms over ea_vols: membership of each cited pair (counts only were printed)
ea = ",".join("'%s'" % v for v in vols("ea_vols.txt"))
terms = ['"Department of State"', '"psychological warfare"', '"psychological strategy"', 'psychological', '"information program"', 'USIS', 'USIA', 'propaganda', '"Voice of America"', '"image of the United States"', '"American image"', '"United States prestige"', '"American prestige"', '"U.S. prestige"', '"Asian opinion"', '"Asian peoples"', '"Asian attitudes"', '"exchange of persons"', '"cultural exchange"', '"Operations Coordinating Board"', '"psychological impact"', '"public opinion"', 'colonialism', '"racial discrimination"', '"Little Rock"', '"face"', '"Asian mind"', '"Oriental mind"', '"Asians"']
fts_hits = {}
for t in terms:
    rows = set(a + "/" + b for a, b in c.execute(f"SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH ? AND dc.volume_id IN ({ea}) AND dc.is_front_matter=0 AND dc.is_editorial_note=0", (t,)))
    fts_hits[t] = rows

print()
print("=== cited pair -> saved/printed result sets that hold it (STRICT) ===")
strict_ok = 0
for p in cited:
    hits = [k for k, s in sets.items() if p in s]
    scan_hits = [t for t, s in fts_hits.items() if p in s and t != '"Department of State"' and t != '"face"' and t != 'psychological' and t != 'propaganda' and t != '"public opinion"' and t != '"Asians"' and t != 'colonialism']
    flag = "REACHED" if hits else ("count-scan-only" if scan_hits else "UNREACHED")
    if hits: strict_ok += 1
    print(f"{p:28s} {flag:16s} {hits}  fts_scan terms (ea only, counts printed): {scan_hits[:6]}")
print("strictly reached by a saved/printed result set:", strict_ok, "of", len(cited))

# order of first appearance in the log (dump calls) vs the vectors step (log line 37)
print()
print("=== when was each cited pair first dumped (log line) ===")
log = open(RUN + "queries.log", encoding="utf-8").read().split("\n")
for p in cited:
    first = next((i + 1 for i, l in enumerate(log) if p in l), None)
    print(f"{p:28s} first named on log line {first}")
