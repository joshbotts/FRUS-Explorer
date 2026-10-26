# From out/headings.tsv write out/doc_sections.tsv: volume_id, document_id, breadcrumb (the deepest section listing the doc).
import csv, sys
csv.field_size_limit(10**9)
rows = {}
with open("out/headings.tsv") as f:
    r = csv.reader(f, delimiter="\t", quoting=csv.QUOTE_NONE)
    next(r)
    for vol, depth, crumb, title, n, ids in r:
        if not ids: continue
        for d in ids.split(","):
            key = (vol, d)
            # keep the deepest breadcrumb if listed twice
            if key not in rows or int(depth) > rows[key][0]:
                rows[key] = (int(depth), crumb)
with open("out/doc_sections.tsv", "w") as o:
    o.write("volume_id\tdocument_id\tdepth\tbreadcrumb\n")
    for (vol, d), (dep, crumb) in sorted(rows.items()):
        o.write(f"{vol}\t{d}\t{dep}\t{crumb}\n")
print("docs mapped", len(rows))
