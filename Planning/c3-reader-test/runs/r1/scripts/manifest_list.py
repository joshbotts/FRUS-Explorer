# write work/manifest_list.tsv: volumeId, subseries, earliest, latest, publicationDate, status, collapsed title
import json, re
R = "/Applications/FRUS Explorer.app/Contents/Resources"
m = json.load(open(R + "/manifest.json"))
with open("/Users/jbotts/frus-analysis/c3/runs/r1/work/manifest_list.tsv", "w") as f:
    f.write("volumeId\tsubseries\tearliest\tlatest\tpubdate\tstatus\ttitle\n")
    for v in m:
        t = re.sub(r"\s+", " ", v.get("title") or "").strip()
        dr = v.get("dateRange") or {}
        f.write("\t".join([v["volumeId"], str(v.get("subseries")), str(dr.get("earliest")), str(dr.get("latest")), str(v.get("publicationDate")), str(v.get("status")), t]) + "\n")
print(len(m), "volumes written")
