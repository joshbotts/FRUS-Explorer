# Reading accounting from out/reading_log.tsv (written by read_docs.py) and quotes/quotes_verified.json.
import csv, json
rows = list(csv.reader(open("out/reading_log.tsv"), delimiter="\t"))
pairs = {}
for v, d, blen, cap, w in rows: pairs[(v, d)] = (int(blen), int(cap), w)
print("read_docs.py retrievals:", len(rows), "| distinct documents:", len(pairs), "| retrieved whole (captured = length(body_text)):", sum(1 for x in pairs.values() if x[2] == "whole"),
      "| total characters retrieved:", sum(x[1] for x in pairs.values()))
q = json.load(open("quotes/quotes_verified.json"))
qp = sorted({x["pair"] for x in q})
print("quotations verified:", len(q), "| documents with a verified quotation:", len(qp))
print("documents retrieved:", ", ".join(f"{v}/{d}" for v, d in sorted(pairs)))
coll = [p for f, p in csv.reader(open("out/collection_pairs.tsv"), delimiter="\t")]
print("retrieved but not in collection:", sorted(f"{v}/{d}" for v, d in pairs if f"{v}/{d}" not in coll))
