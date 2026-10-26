# Decade denominators from out/doc_paths.tsv (built by 05_doc_paths.py from document_cache + document_dates):
# dated non-apparatus documents (is_front_matter=0 AND is_editorial_note=0 AND date_iso not empty AND isdoc=1, i.e.
# document_id GLOB 'd[0-9]*' OR '*_d[0-9]*'), corpus-wide and in the
# Latin American universe, by decade of date_iso (the index's document date = TEI frus:doc-dateTime-min day).
# Ed2 suppression: frus1951-54IranEd2 and frus1969-76ve15p2Ed2 dropped (first editions kept; frus1977-80v09Ed2 kept).
import collections
DROP = {"frus1951-54IranEd2", "frus1969-76ve15p2Ed2"}
allc = collections.Counter(); lac = collections.Counter(); undated = collections.Counter()
for line in open("/Users/jbotts/frus-analysis/c3/runs/r10/out/doc_paths.tsv"):
    v, d, fm, ed, di, la, p, isdoc = line.rstrip("\n").split("\t")
    if v in DROP or fm == "1" or ed == "1" or isdoc != "1":
        continue
    if not di:
        undated["la" if la == "1" else "other"] += 1
        continue
    dec = di[:3] + "0s"
    allc[dec] += 1
    if la == "1":
        lac[dec] += 1
print("decade\tall_dated_nonapparatus\tLA_dated_nonapparatus")
for dec in sorted(allc):
    print("%s\t%d\t%d" % (dec, allc[dec], lac[dec]))
print("TOTAL\t%d\t%d" % (sum(allc.values()), sum(lac.values())))
print("undated non-apparatus:", dict(undated))
