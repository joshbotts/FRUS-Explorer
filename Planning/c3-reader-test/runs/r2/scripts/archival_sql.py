# Came-from channel (document_sources, one row per document) and pointed-at channel (external_citations, many rows per
# document) for the scope set, NEVER summed. Both joined on (volume_id, document_id) through a VALUES list of the scope pairs
# (out/ff_ids_scope.tsv; statements saved to out/arch_sql_*.sql).
import csv, sqlite3, json
from collections import Counter
csv.field_size_limit(10**9)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
scope = list(csv.DictReader(open("out/scope.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
pairs = sorted({(r["volume_id"], r["document_id"]) for r in scope})
tier = {(r["volume_id"], r["document_id"]): r["tier"] for r in scope}
vals = ",".join("('%s','%s')" % p for p in pairs)
open("out/ff_ids_scope.tsv", "w").write("".join(f"{v}\t{d}\n" for v, d in pairs))
SQL_DS = (f"WITH s(v, d) AS (VALUES {vals}) SELECT ds.volume_id, ds.document_id, ds.repository, ds.record_group, ds.lot_file_norm, "
          f"ds.series_name, ds.citation_era, ds.decimal_class, ds.raw_text FROM document_sources ds JOIN s ON ds.volume_id = s.v AND ds.document_id = s.d")
SQL_EC = (f"WITH s(v, d) AS (VALUES {vals}) SELECT ec.volume_id, ec.document_id, ec.note_ordinal, ec.citation_index, ec.anchor, ec.repository, "
          f"ec.collection, ec.lot_file_norm, ec.file_id, ec.decimal_class, ec.inherited, ec.raw_text FROM external_citations ec JOIN s ON ec.volume_id = s.v AND ec.document_id = s.d")
open("out/arch_sql_document_sources.sql", "w").write(SQL_DS + ";\n")
open("out/arch_sql_external_citations.sql", "w").write(SQL_EC + ";\n")
open("out/sql_trace.log", "a").write("[archival_sql.py] statements in out/arch_sql_document_sources.sql and out/arch_sql_external_citations.sql\n")
ds = con.execute(SQL_DS).fetchall(); ec = con.execute(SQL_EC).fetchall()
with open("out/arch_document_sources.tsv", "w") as f:
    f.write("volume_id\tdocument_id\ttier\trepository\trecord_group\tlot_file_norm\tseries_name\tcitation_era\tdecimal_class\traw_text\n")
    for r in ds: f.write("\t".join([r[0], r[1], tier[(r[0], r[1])]] + [" ".join(str(x or "").split()) for x in r[2:]]) + "\n")
with open("out/arch_external_citations.tsv", "w") as f:
    f.write("volume_id\tdocument_id\ttier\tnote_ordinal\tcitation_index\tanchor\trepository\tcollection\tlot_file_norm\tfile_id\tdecimal_class\tinherited\traw_text\n")
    for r in ec: f.write("\t".join([r[0], r[1], tier[(r[0], r[1])]] + [" ".join(str(x if x is not None else "").split()) for x in r[2:]]) + "\n")
print("scope docs", len(pairs), "| document_sources rows", len(ds), "| external_citations rows", len(ec), "(docs with >=1:", len({(r[0], r[1]) for r in ec}), ")")
print("came-from citation_era:", Counter(r[6] for r in ds).most_common())
print("came-from repository:", Counter(r[2] for r in ds).most_common(12))
print("came-from record_group:", Counter(r[3] for r in ds).most_common(12))
print("came-from decimal_class top:", Counter(r[7] for r in ds if r[7]).most_common(25))
print("came-from series_name top:", Counter(r[5] for r in ds if r[5]).most_common(15))
print("came-from lot_file_norm top:", Counter(r[4] for r in ds if r[4]).most_common(15))
print("pointed-at anchor:", Counter(r[4] for r in ec).most_common())
print("pointed-at repository:", Counter(r[5] for r in ec).most_common(10))
print("pointed-at collection top:", Counter(r[6] for r in ec if r[6]).most_common(15))
print("pointed-at lot top:", Counter(r[7] for r in ec if r[7]).most_common(15))
print("pointed-at decimal_class top:", Counter(r[9] for r in ec if r[9]).most_common(20))
