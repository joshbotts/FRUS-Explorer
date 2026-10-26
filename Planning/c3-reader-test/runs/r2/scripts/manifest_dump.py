# Dump manifest volumes: id, title (collapsed), date range, publication date, subseries, LatAm tags.
import json, re, sys
m = json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
LATAM = ["mexico","guatemala","honduras","el-salvador","nicaragua","costa-rica","panama","cuba","haiti",
         "dominican-republic","colombia","venezuela","ecuador","peru","bolivia","chile","argentina",
         "uruguay","paraguay","brazil","latin-america","american-republics"]
out = open("out/manifest_volumes.tsv","w")
out.write("volumeId\ttitle\tearliest\tlatest\tpub\tsubseries\tlatam_tags\n")
for v in m:
    t = re.sub(r"\s+"," ",v.get("title","")).strip()
    tags = v.get("tags",[]) or []
    lt = [x for x in tags if x in LATAM]
    dr = v.get("dateRange") or {}
    out.write("\t".join([v["volumeId"], t, str(dr.get("earliest",""))[:10], str(dr.get("latest",""))[:10],
                         str(v.get("publicationDate","")), str(v.get("subseries","")), ",".join(lt)])+"\n")
out.close()
print("wrote out/manifest_volumes.tsv")
