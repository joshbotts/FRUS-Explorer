# List manifest volumes whose title or tags mention Latin America (regional or country), with coverage dates.
import json, re
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
m = json.load(open(RES + "manifest.json"))
LA = re.compile(r"Argentin|Bolivi|Brazil|Chile|Colombia|Costa Rica|Cuba|Dominican|Ecuador|Salvador|Guatemala|Haiti|"
                r"Honduras|Mexic|Nicaragua|Panam|Paraguay|Peru|Uruguay|Venezuela|Central America|American Republics|"
                r"Latin America|Western Hemisphere|Inter-American|Caribbean|South America|Guyana", re.I)
print("keys of a manifest row:", sorted(m[0].keys()))
n = 0
for v in m:
    t = re.sub(r"\s+", " ", v.get("title") or "")
    if LA.search(t):
        n += 1
        dr = v.get("dateRange") or {}
        print("%s\t%s\t%s..%s\t%s" % (v["volumeId"], v.get("subseries"), (dr.get("earliest") or "")[:10], (dr.get("latest") or "")[:10], t[:150]))
print("volumes whose TITLE names Latin America:", n)
