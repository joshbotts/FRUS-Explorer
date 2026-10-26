# Read decimal-class-labels.json: print coverage block, each schedule's title/years/keys, and the glosses (where the
# file has them) for the decimal classes named on the command line (country part + subject part), honoring the
# file's own gate (coverage.glossableYears): a class is glossed only against a schedule whose span covers the year
# given with it (argv items "835.01@1930").
import json, sys
d = json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/decimal-class-labels.json"))
print("coverage:", json.dumps(d["coverage"])[:3000])
for s in d["schedules"]:
    print("schedule keys:", sorted(s.keys()))
    print("  meta:", {k: (v if not isinstance(v, (dict, list)) else ("%s len=%d" % (type(v).__name__, len(v)))) for k, v in s.items()})
    for k in ("subjects", "subclasses", "labels", "entries"):
        if k in s:
            items = list(s[k].items())[:5] if isinstance(s[k], dict) else s[k][:5]
            print("  sample", k, json.dumps(items)[:800])
