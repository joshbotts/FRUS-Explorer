# Print the top-level shape of each bundled JSON file named on the command line (first item / keys).
import json, sys
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
for name in sys.argv[1:]:
    d = json.load(open(RES + name))
    print("=====", name, type(d).__name__)
    if isinstance(d, dict):
        for k, v in d.items():
            desc = type(v).__name__
            if isinstance(v, (list, dict)):
                desc += " len=%d" % len(v)
            else:
                desc += " = " + repr(v)[:200]
            print("  key:", k, desc)
        for k, v in d.items():
            if isinstance(v, list) and v:
                print("  first of", k, ":", json.dumps(v[0])[:1500])
            elif isinstance(v, dict) and v and k not in ("legend",):
                kk = list(v.keys())[0]
                print("  first of", k, ":", kk, "->", json.dumps(v[kk])[:1500])
            elif k == "legend":
                print("  legend:", json.dumps(v)[:3000])
    else:
        print("  len", len(d))
        print("  first:", json.dumps(d[0])[:2500])
