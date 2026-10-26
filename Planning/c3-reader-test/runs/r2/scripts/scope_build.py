# SCOPE = T ∪ C_all
#   T     = out/scope_text.tsv (Latin American sections, apparatus excluded, text rule; see scope_text.py)
#   C_all = every non-apparatus document directly listed in the curated single-topic recognition chapters
#           (ids below refer to rows of out/chapter_candidates.tsv; 184 = frus1948v09 "Continuance ... Bogota Resolution")
# Writes out/scope.tsv (volume_id, document_id, date_iso, country, tier, chapter_idx, header) and out/scope_chapters.tsv.
import csv, sqlite3
csv.field_size_limit(10**9)
C_ALL = [1,7,8,9,19,20,21,36,48,77,86,100,101,102,106,108,110,112,113,115,117,118,121,127,128,141,148,153,154,
         155,157,162,163,164,165,166,168,169,170,171,172,173,174,176,177,178,179,180,181,184,185]
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
trace = open("out/sql_trace.log", "a")
cand = {}
with open("out/chapter_candidates.tsv") as f:
    for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
        cand[int(r["idx"])] = r
# recover full doc id lists for the chosen sections from headings.tsv (match volume + breadcrumb prefix)
heads = []
with open("out/headings.tsv") as f:
    for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
        heads.append(r)
chap_docs = {}
chap_rows = []
for i in C_ALL:
    c = cand[i]
    hits = [h for h in heads if h["volume_id"] == c["volume_id"] and h["breadcrumb"][:400] == c["title"] and h["doc_ids"]]
    assert len(hits) == 1, (i, len(hits))
    h = hits[0]
    ids = h["doc_ids"].split(",")
    chap_rows.append((i, h["volume_id"], len(ids), h["breadcrumb"]))
    for d in ids:
        chap_docs[(h["volume_id"], d)] = i
latam = {}
with open("out/latam_docs.tsv") as f:
    for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
        latam[(r["volume_id"], r["document_id"])] = r["country"]
T = {}
with open("out/scope_text.tsv") as f:
    for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
        T[(r["volume_id"], r["document_id"])] = r
keys = set(T) | set(chap_docs)
sql = """SELECT c.volume_id, c.document_id, c.is_front_matter, c.is_editorial_note, d.date_iso, c.header
         FROM document_cache c LEFT JOIN document_dates d ON d.volume_id = c.volume_id AND d.document_id = c.document_id
         WHERE c.volume_id = ? AND c.document_id = ?"""
trace.write("[scope_build.py] " + " ".join(sql.split()) + "  -- run once per (volume_id, document_id) in T ∪ C_all\n")
out = []; dropped_app = 0; missing = 0
for k in sorted(keys):
    r = con.execute(sql, k).fetchone()
    if r is None: missing += 1; continue
    if r[2] or r[3]: dropped_app += 1; continue
    tier = "T+C" if (k in T and k in chap_docs) else ("T" if k in T else "C")
    out.append((k[0], k[1], r[4] or "", latam.get(k, "?"), tier, str(chap_docs.get(k, "")), " ".join((r[5] or "").split())))
with open("out/scope.tsv", "w") as o:
    o.write("volume_id\tdocument_id\tdate_iso\tcountry\ttier\tchapter_idx\theader\n")
    for row in out: o.write("\t".join(row) + "\n")
with open("out/scope_chapters.tsv", "w") as o:
    o.write("idx\tvolume_id\tn_docs_listed\tbreadcrumb\n")
    for row in chap_rows: o.write("\t".join(map(str, row)) + "\n")
from collections import Counter
print("T", len(T), "| C_all docs listed", len(chap_docs), "| union", len(keys), "| apparatus dropped", dropped_app, "| missing", missing, "| SCOPE", len(out))
print(Counter(r[4] for r in out))
