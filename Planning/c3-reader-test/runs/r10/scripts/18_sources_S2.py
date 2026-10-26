# Came-from channel over the scope S2: document_sources rows for every S2 document (one row per document), grouped
# by citation_era, repository/record group/series, decimal class and lot. Writes out/18_ds_S2.tsv (one row per doc).
# SQL run (15 per call): SELECT volume_id, document_id, repository, record_group, lot_file, lot_file_norm, series_name,
#   citation_era, raw_text, decimal_class FROM document_sources WHERE (volume_id, document_id) IN (VALUES (?,?),...);
import sqlite3, collections
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
S2 = []
for line in open(R + "out/scope_S2.tsv"):
    f = line.rstrip("\n").split("\t"); S2.append((f[0], f[1], f[2]))
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows = []
for i in range(0, len(S2), 15):
    chunk = S2[i:i + 15]
    q = "SELECT volume_id, document_id, repository, record_group, lot_file, lot_file_norm, series_name, citation_era, raw_text, decimal_class FROM document_sources WHERE (volume_id, document_id) IN (VALUES %s)" % ",".join(["(?,?)"] * len(chunk))
    rows += con.execute(q, [x for k in chunk for x in k[:2]]).fetchall()
dates = {(v, d): di for v, d, di in S2}
with open(R + "out/18_ds_S2.tsv", "w") as f:
    for r in rows:
        f.write("\t".join("" if x is None else str(x).replace("\t", " ").replace("\n", " ") for x in (r[0], r[1], dates[(r[0], r[1])]) + r[2:]) + "\n")
print("S2 documents:", len(S2), " with a document_sources row:", len(rows))
c_era = collections.Counter(r[7] for r in rows)
print("citation_era (a citation FORM, not a date):", c_era.most_common())
c_rep = collections.Counter((r[2] or "-", r[3] or "-") for r in rows)
print("repository / record_group:", c_rep.most_common(15))
c_ser = collections.Counter((r[6] or "-") for r in rows)
print("series_name top:", c_ser.most_common(20))
c_lot = collections.Counter((r[5] or "-") for r in rows if r[5])
print("lot_file_norm:", c_lot.most_common(30))
c_dec = collections.Counter((r[9] or "-") for r in rows if r[9])
print("decimal_class top 40:", c_dec.most_common(40))
