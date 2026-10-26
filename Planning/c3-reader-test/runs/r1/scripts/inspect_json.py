# usage: inspect_json.py FILE  -- print top-level keys, types and a short sample (no analysis)
import json, sys
p = sys.argv[1]
d = json.load(open(p))
def desc(x, depth=0, maxd=2):
    pad = "  " * depth
    if isinstance(x, dict):
        print(pad + "dict(%d): %s" % (len(x), list(x.keys())[:25]))
        if depth < maxd:
            for k in list(x.keys())[:12]:
                print(pad + " key %r ->" % k)
                desc(x[k], depth + 1, maxd)
    elif isinstance(x, list):
        print(pad + "list(%d)" % len(x))
        if x and depth < maxd:
            print(pad + " first item:")
            desc(x[0], depth + 1, maxd)
    else:
        s = repr(x)
        print(pad + s[:160])
desc(d)
