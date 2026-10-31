# presidential-library-catalog.json: find series rows for the libraries/series the set came from
import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
p=json.load(open(R+"presidential-library-catalog.json")); print("keys",list(p.keys()))
for k,v in p.items():
    if isinstance(v,list): print(k,len(v), json.dumps(v[0],ensure_ascii=False)[:400])
    elif isinstance(v,dict): print(k,"dict",len(v), json.dumps(next(iter(v.items())),ensure_ascii=False)[:400])
