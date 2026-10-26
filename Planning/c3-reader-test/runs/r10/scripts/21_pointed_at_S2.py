# Pointed-at channel over the scope S2: external_citations rows (what the editors' footnotes MENTION; many rows per
# document) for the S2 documents. Grouped by anchor kind, repository/collection, lot, decimal class.
# SQL run (15 per call): SELECT volume_id, document_id, note_ordinal, citation_index, anchor, repository, collection,
#   lot_file, lot_file_norm, file_id, inherited, raw_text, decimal_class FROM external_citations
#   WHERE (volume_id, document_id) IN (VALUES (?,?),...);
import sqlite3, collections
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
S2 = []
for line in open(R + "out/scope_S2.tsv"):
    f = line.rstrip("\n").split("\t"); S2.append((f[0], f[1], f[2]))
dates = {(v, d): di for v, d, di in S2}
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows = []
for i in range(0, len(S2), 15):
    chunk = S2[i:i + 15]
    q = "SELECT volume_id, document_id, note_ordinal, citation_index, anchor, repository, collection, lot_file, lot_file_norm, file_id, inherited, raw_text, decimal_class FROM external_citations WHERE (volume_id, document_id) IN (VALUES %s)" % ",".join(["(?,?)"] * len(chunk))
    rows += con.execute(q, [x for k in chunk for x in k[:2]]).fetchall()
with open(R + "out/21_ec_S2.tsv", "w") as f:
    for r in rows:
        f.write("\t".join("" if x is None else str(x).replace("\t", " ").replace("\n", " ") for x in (r[0], r[1], dates[(r[0], r[1])]) + r[2:]) + "\n")
docs = {(r[0], r[1]) for r in rows}
print("S2 documents:", len(S2), " external_citations rows:", len(rows), " documents with at least one row:", len(docs))
print("anchor kinds:", collections.Counter(r[4] for r in rows).most_common())
print("inherited:", collections.Counter(r[10] for r in rows).most_common())
print("repository/collection top:", collections.Counter((r[5] or "-", r[6] or "-") for r in rows).most_common(25))
print("lot_file_norm:", collections.Counter(r[8] for r in rows if r[8]).most_common(30))
print("decimal_class top 30:", collections.Counter(r[12] for r in rows if r[12]).most_common(30))
print("earliest dated document with a row:", min(dates[k] for k in docs if dates[k]) if docs else None)
