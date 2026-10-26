# probe the meaning of collection-usage-index.json by comparing a few volumes' counts with the index copy's document_sources / external_citations row counts
import json, sys
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
R = "/Applications/FRUS Explorer.app/Contents/Resources"
d = json.load(open(R + "/collection-usage-index.json"))
print("categories:", d["categories"])
vols = d["volumes"]
conn = frus.connect()
for vid in ["frus1933v05", "frus1944v07", "frus1961-63v12", "frus1913"]:
    i = vols.index(vid)
    ds = frus.sql(conn, "SELECT COUNT(*) FROM document_sources WHERE volume_id = ?", (vid,), script="scripts/usage_probe.py")[0][0]
    ec = frus.sql(conn, "SELECT COUNT(*), COUNT(DISTINCT document_id) FROM external_citations WHERE volume_id = ?", (vid,), script="scripts/usage_probe.py")[0]
    percat = {}
    for c in d["volumeCategories"]:
        if i in c["v"]:
            percat[d["categories"][c["k"]]] = c["n"][c["v"].index(i)]
    print(vid, "volumeNoteCounts:", d["volumeNoteCounts"][i], "| document_sources rows:", ds, "| external_citations rows/docs:", ec, "| per category:", percat)
