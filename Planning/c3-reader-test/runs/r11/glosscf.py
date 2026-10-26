# Gloss came-from decimal keys with the 1910-1949 schedule only for documents dated 1910-1949 (decimal-class-labels.json); others counted as not glossed
import json,collections,re
from db import q
R="/Applications/FRUS Explorer.app/Contents/Resources"
d=json.load(open(R+"/decimal-class-labels.json")); s=[x for x in d['schedules'] if x['id']=='1910-1949'][0]
rows=json.load(open("arch_rows.json"))["camefrom"]
dates=dict(((v,dd),di) for v,dd,di in q("SELECT volume_id, document_id, date_iso FROM document_dates",tag="glosscf"))
c=collections.Counter(); outside=0; dec=0
for r in rows:
    if r[6]!="decimal" or not r[7]: continue
    dec+=1; di=dates[(r[0],r[1])][:4]
    if not ("1910"<=di<="1949"): outside+=1; continue
    m=re.match(r"^(\d)(\d\d[a-z]?)\.(\w+)",r[7])
    if not m: c[(r[7],"unparsed")]+=1; continue
    cls,ctry,sub=m.groups()
    lab=s['countries'].get(ctry,"?")+" / "+(s['subjects'][cls].get(sub[:2],"?") if cls in s['subjects'] else s['classes'].get(cls,"?"))
    c[(cls+ctry+"."+sub[:2],lab)]+=1
print("decimal came-from rows with a class",dec,"; dated outside 1910-1949 (not glossed):",outside)
for k,n in c.most_common(): print(n,k)
