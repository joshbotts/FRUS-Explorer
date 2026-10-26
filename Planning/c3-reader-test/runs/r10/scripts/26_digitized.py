# digitized-ranges-index.json: its seriesNaIds (with series-facts rows) and the digitised ranges whose decimalClass
# shares the country-and-class prefix of the scope's came-from classes (out/18_ds_S2.tsv), e.g. 824.00, 816.01.
import json, collections
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
dr = json.load(open(RES + "digitized-ranges-index.json"))
sf = json.load(open(RES + "series-facts-index.json"))
print("seriesNaIds:", dr["seriesNaIds"])
for n in dr["seriesNaIds"]:
    print("  series-facts", n, sf["byNaId"].get(n))
rs = json.load(open(RES + "roll-scans-index.json"))
print("roll-scans seriesNaId:", rs["seriesNaId"], sf["byNaId"].get(rs["seriesNaId"]))
classes = collections.Counter(r["decimalClass"] for r in dr["ranges"])
print("distinct digitised decimal classes:", len(classes), "sample:", list(classes)[:40])
came = collections.Counter()
for line in open(R + "out/18_ds_S2.tsv"):
    f = line.rstrip("\n").split("\t")
    if len(f) > 10 and f[10]: came[f[10]] += 1
hits = [(c, n) for c, n in came.items() if c in classes]
print("scope came-from classes with a digitised range:", len(hits), "of", len(came), hits[:20])
