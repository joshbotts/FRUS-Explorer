# usage: peek_json.py FILE KEY [N] -- print the first N items (default 3) of top-level KEY as compact JSON
import json, sys
d = json.load(open(sys.argv[1]))
k = sys.argv[2]; n = int(sys.argv[3]) if len(sys.argv) > 3 else 3
x = d[k]
if isinstance(x, list):
    print("list of", len(x))
    for i in x[:n]:
        print(json.dumps(i, ensure_ascii=False)[:700])
elif isinstance(x, dict):
    print("dict of", len(x))
    for kk in list(x)[:n]:
        print(kk, json.dumps(x[kk], ensure_ascii=False)[:700])
else:
    print(json.dumps(x, ensure_ascii=False)[:1500])
