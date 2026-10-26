import json, os
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
def peek(name, depth=2):
    d = json.load(open(R+name))
    print("=====", name, type(d).__name__)
    def show(x, ind, lvl):
        if lvl > depth: return
        if isinstance(x, dict):
            for k in list(x.keys())[:12]:
                v = x[k]
                if isinstance(v, (dict, list)):
                    print(" "*ind + f"{k}: {type(v).__name__}[{len(v)}]")
                    show(v, ind+2, lvl+1)
                else:
                    print(" "*ind + f"{k}: {repr(v)[:100]}")
            if len(x) > 12: print(" "*ind + f"... {len(x)-12} more keys")
        elif isinstance(x, list) and x:
            print(" "*ind + f"[0] of {len(x)}:")
            show(x[0], ind+2, lvl+1)
    show(d, 0, 0)
for n in ["external-citation-index.json","collection-usage-index.json","collection-authority.json","series-facts-index.json","volume-sources-index.json","lot-claimants-index.json","curated-lot-resolutions.json","presidential-library-catalog.json","central-files-index.json","source-provenance-index.json"]:
    peek(n, 3)
