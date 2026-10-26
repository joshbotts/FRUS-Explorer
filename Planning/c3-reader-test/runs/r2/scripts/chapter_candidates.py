# Candidate editors' chapters: sections (out/headings.tsv) whose OWN title uses the recognition/force
# formula and whose documents classify as Latin American (out/latam_docs.tsv). Writes out/chapter_candidates.tsv.
import csv, re
csv.field_size_limit(10**9)
latam = {}
with open("out/latam_docs.tsv") as f:
    for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
        latam[(r["volume_id"], r["document_id"])] = r["country"]
PAT = r"recogni|revolution|coup|junta|de facto|provisional (government|president)|overthrow|insurrection|uprising|seizure of (the )?(executive )?power|unconstitutional|diplomatic relations with new governments|continuance of diplomatic relations|nonintervention and nonrecognition|article ii of the general treaty"
out = open("out/chapter_candidates.tsv", "w"); out.write("idx\tvolume_id\tn_docs\tn_latam\tcountry\ttitle\n")
i = 0
with open("out/headings.tsv") as f:
    for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
        ids = [x for x in r["doc_ids"].split(",") if x]
        if not ids or not re.search(PAT, r["title"].lower()): continue
        cs = [latam.get((r["volume_id"], d)) for d in ids]
        nl = sum(1 for c in cs if c)
        if nl == 0: continue
        cc = sorted(set(c for c in cs if c))
        i += 1
        out.write(f"{i}\t{r['volume_id']}\t{len(ids)}\t{nl}\t{'/'.join(cc)}\t{r['breadcrumb'][:400]}\n")
out.close(); print("candidates", i)
