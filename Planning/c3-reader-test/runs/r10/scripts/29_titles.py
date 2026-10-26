# Print manifest titles (whitespace-collapsed) for the volumes named on the command line.
import json, re, sys
m = {v["volumeId"]: v for v in json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))}
for vid in sys.argv[1:]:
    v = m.get(vid)
    print("%s\t%s" % (vid, re.sub(r"\s+", " ", v["title"]) if v else "NOT IN MANIFEST"))
