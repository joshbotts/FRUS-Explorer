# collection-authority.json / collection-usage-index.json: find Central Files and library series records
import json,re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ca=json.load(open(R+"collection-authority.json")); cu=json.load(open(R+"collection-usage-index.json"))
print("authority keys",list(ca.keys())); print("usage keys",list(cu.keys()))
recs=ca.get("records") or ca.get("collections") or []
print("records type",type(recs),len(recs)); 
first = recs[0] if isinstance(recs,list) else next(iter(recs.items()))
print("sample",json.dumps(first,ensure_ascii=False)[:600])
