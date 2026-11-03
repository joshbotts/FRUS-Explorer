#!/usr/bin/env python3
# Document identity on three surfaces, read-only: the TEI's <div type="document"> xml:ids in
# document order, the vectors index's run-length segments decoded as guide §A.3 prints the decode,
# and the index copy's document_cache ids.
# argv: <volumes dir> <manifest.json> <semantic-vectors-index.json> <index copy .db> <out prefix>
import json, os, sqlite3, sys, time
import xml.etree.ElementTree as ET

TEI = "{http://www.tei-c.org/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"

def numeric_part(doc_id):
    if not doc_id.startswith("d"): return None
    digits = doc_id[1:]
    if not digits or not digits.isdigit(): return None
    if len(digits) > 1 and digits[0] == "0": return None
    return int(digits)

def decode_segments(segments):
    ids = []
    for seg in segments:
        assert seg["s"] == len(ids)
        ids.append(seg["i"])
        if seg["n"] > 1:
            base = numeric_part(seg["i"])
            ids.extend(f"d{base + k}" for k in range(1, seg["n"]))
    return ids

vol_dir, manifest, vec_index, db, prefix = sys.argv[1:6]
files = [v["filename"] for v in json.load(open(manifest))]
vec = {e["v"]: decode_segments(e["seg"]) for e in json.load(open(vec_index))["volumes"]}
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
dc = {}
for v, d in con.execute("SELECT volume_id, document_id FROM document_cache"):
    dc.setdefault(v, set()).add(d)

t0 = time.perf_counter()
set_differs = order_differs = tei_not_in_dc = 0
tei_total = dc_total = dc_not_tei = 0
examples = []
with open(prefix + "-volumes.tsv", "w") as out:
    out.write("volume\ttei\tvec\tsame_set\tsame_order\ttei_missing_from_index\tindex_rows_not_tei\n")
    for name in files:
        v = name[:-4]
        root = ET.parse(os.path.join(vol_dir, name)).getroot()
        tei = [d.get(XMLID) for d in root.iter(TEI + "div") if d.get("type") == "document"]
        vids = vec.get(v, [])
        same_set = set(tei) == set(vids)
        same_order = tei == vids
        missing = [i for i in tei if i not in dc.get(v, set())]
        extra = dc.get(v, set()) - set(tei)
        set_differs += not same_set; order_differs += not same_order
        tei_not_in_dc += len(missing); tei_total += len(tei)
        dc_total += len(dc.get(v, set())); dc_not_tei += len(extra)
        if (not same_set or not same_order or missing) and len(examples) < 10:
            examples.append((v, len(tei), len(vids), same_set, same_order, missing[:3]))
        out.write(f"{v}\t{len(tei)}\t{len(vids)}\t{int(same_set)}\t{int(same_order)}\t{len(missing)}\t{len(extra)}\n")
print(f"pass {time.perf_counter() - t0:.1f}s over {len(files)} volumes")
print("TEI documents", tei_total, "| volumes whose TEI and vector id SETS differ", set_differs,
      "| whose ORDER differs", order_differs)
print("TEI documents with no index row", tei_not_in_dc, "| index rows", dc_total,
      "| index rows that are no TEI document", dc_not_tei)
for e in examples: print("example", e)
