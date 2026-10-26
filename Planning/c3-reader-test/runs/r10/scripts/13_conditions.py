# Condition families (scripts/conditions.json) in the scope set S2 (out/scope_S2.tsv) and in the Latin American
# universe (out/doc_paths.tsv, la_flag=1), by era of the document date (date_iso), with a CENSUS literal share over
# every S2 hit (strict and tolerant regex, Python re, IGNORECASE, on header+dateline+source_note+body_text,
# whitespace-collapsed). Writes out/cond_hits_<family>.tsv (S2 hits with strict/tolerant flags).
# SQL run per family: SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c
#   ON c.volume_id=f.volume_id AND c.document_id=f.document_id
#   WHERE frus_documents MATCH :expr AND c.is_front_matter=0 AND c.is_editorial_note=0;
# Text SQL (15 per call): SELECT volume_id, document_id, header, dateline, source_note, body_text FROM document_cache
#   WHERE (volume_id, document_id) IN (VALUES (?,?),...);
import json, re, sqlite3, collections, sys
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
DROP = {"frus1951-54IranEd2", "frus1969-76ve15p2Ed2"}
fams = json.load(open(R + "scripts/conditions.json"))
def era(di):
    if not di: return "undated"
    if di < "1913": return "E1_to1912"
    if di < "1930": return "E2_1913-29"
    if di < "1943": return "E3_1930-42"
    if di < "1949": return "E4_1943-48"
    if di < "1961": return "E5_1949-60"
    return "E6_1961-88"
ERAS = ["E1_to1912", "E2_1913-29", "E3_1930-42", "E4_1943-48", "E5_1949-60", "E6_1961-88"]
meta = {}
for line in open(R + "out/doc_paths.tsv"):
    v, d, fm, ed, di, la, p, isdoc = line.rstrip("\n").split("\t")
    if fm == "0" and ed == "0" and v not in DROP and isdoc == "1":
        meta[(v, d)] = (di, la)
S2 = {}
for line in open(R + "out/scope_S2.tsv"):
    f = line.rstrip("\n").split("\t")
    S2[(f[0], f[1])] = f[2]
s2_era = collections.Counter(era(di) for di in S2.values())
la_era = collections.Counter(era(di) for (k, (di, la)) in meta.items() if la == "1")
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
# load S2 texts once
texts = {}
keys = sorted(S2)
for i in range(0, len(keys), 15):
    chunk = keys[i:i + 15]
    q = "SELECT volume_id, document_id, header, dateline, source_note, body_text FROM document_cache WHERE (volume_id, document_id) IN (VALUES %s)" % ",".join(["(?,?)"] * len(chunk))
    for v, d, h, dl, sn, b in con.execute(q, [x for k in chunk for x in k]):
        texts[(v, d)] = " ".join(" ".join([h or "", dl or "", sn or "", b or ""]).split())
print("S2 documents:", len(S2), "texts loaded:", len(texts), "characters:", sum(len(t) for t in texts.values()))
print("S2 by era:", dict(s2_era)); print("LA universe (dated non-apparatus) by era:", dict(la_era))
print()
print("family\tera\tS2_hits\tS2_N\tS2_per1000\tLA_hits\tLA_N\tLA_per1000")
summary = []
for name, spec in fams.items():
    rows = con.execute("""SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c
        ON c.volume_id=f.volume_id AND c.document_id=f.document_id
        WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0""", (spec["expr"],)).fetchall()
    hits = {r for r in rows if r[0] not in DROP}
    s2h = sorted(h for h in hits if h in S2)
    lah = [h for h in hits if h in meta and meta[h][1] == "1"]
    ce_s2 = collections.Counter(era(S2[h]) for h in s2h)
    ce_la = collections.Counter(era(meta[h][0]) for h in lah)
    rs, rt = re.compile(spec["strict"], re.I), re.compile(spec["tolerant"], re.I)
    ns = nt = 0
    with open(R + "out/cond_hits_%s.tsv" % name, "w") as f:
        for h in s2h:
            t = texts[h]
            s = 1 if rs.search(t) else 0; tt = 1 if rt.search(t) else 0
            ns += s; nt += tt
            f.write("%s\t%s\t%s\t%d\t%d\n" % (h[0], h[1], S2[h], s, tt))
    for e in ERAS:
        print("%s\t%s\t%d\t%d\t%.0f\t%d\t%d\t%.1f" % (name, e, ce_s2[e], s2_era[e], 1000.0 * ce_s2[e] / s2_era[e] if s2_era[e] else 0,
              ce_la[e], la_era[e], 1000.0 * ce_la[e] / la_era[e] if la_era[e] else 0))
    summary.append((name, len(s2h), ns, nt, len(lah)))
print()
print("family\tS2_hits(census)\tSTRICT\tTOLERANT\tLA_hits")
for name, n, ns, nt, nl in summary:
    print("%s\t%d\tSTRICT %d of %d\tTOLERANT %d of %d\t%d" % (name, n, ns, n, nt, n, nl))
