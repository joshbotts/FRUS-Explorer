# Compare the index's day (document_dates.date_iso, as copied into scope.db) with the first ten characters of frus:doc-dateTime-min read from the TEI (work/tei/variants_latam_docs.tsv)
import csv, sqlite3, collections
csv.field_size_limit(10**9)
RUN = "/Users/jbotts/frus-analysis/c3/runs/r1"
s = sqlite3.connect("file:%s/work/scope.db?mode=ro" % RUN, uri=True)
idx = {(v, d): di for v, d, di in s.execute("SELECT volume_id, document_id, date_iso FROM scope_docs WHERE latam=1 AND numbered=1 AND apparatus=0 AND ed2_dup=0")}
n = eq = diff = nodate_idx = nodate_tei = dec_diff = 0
ex = []
for r in csv.reader(open(RUN + "/work/tei/variants_latam_docs.tsv"), delimiter="\t"):
    if r[0] == "volume_id": continue
    k = (r[0], r[1])
    if k not in idx: continue
    n += 1
    a = idx[k]; b = r[2][:10] if r[2] else None
    if not a: nodate_idx += 1
    if not b: nodate_tei += 1
    if a and b:
        if a == b: eq += 1
        else:
            diff += 1
            if a[:3] != b[:3]: dec_diff += 1
            if len(ex) < 5: ex.append((k, a, r[2]))
print("scope documents compared:", n, "| same day:", eq, "| different day:", diff, "| of those, different decade:", dec_diff, "| no index date:", nodate_idx, "| no TEI attribute:", nodate_tei)
print("examples of different day:", ex)
