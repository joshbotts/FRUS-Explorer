# Gloss pointed-at decimal keys with the schedule that governs each DOCUMENT's date (decimal-class-labels.json glossableYears); no gloss outside.
import json,collections,re
from db import q
R="/Applications/FRUS Explorer.app/Contents/Resources"
d=json.load(open(R+"/decimal-class-labels.json")); sch={s['id']:s for s in d['schedules']}
gy=d['coverage']['glossableYears']
dates=dict(((v,dd),di) for v,dd,di in q("SELECT volume_id, document_id, date_iso FROM document_dates",tag="glosspa"))
r=json.load(open("arch_rows.json"))['pointedat']
c=collections.Counter()
for x in r:
    if x[2]!='centralFileClass' or not x[6]: continue
    y=int(dates[(x[0],x[1])][:4]); s=[sch[g['scheduleId']] for g in gy if g['startYear']<=y<=g['endYear']]
    if not s: c[(x[6],'no gloss (date %d outside glossable years)'%y)]+=1; continue
    s=s[0]; m=re.match(r'^(\d)(\d\d[a-z]?)\.(\d\d)',x[6])
    if not m: c[(x[6],'unparsed')]+=1; continue
    cl,ct,sub=m.groups()
    subj=s['subjects'].get(cl,{}).get(sub) if isinstance(s['subjects'].get(cl),dict) else None
    c[(x[6],"%s: %s / %s"%(s['id'],s['countries'].get(ct,'?'),subj or s['classes'].get(cl,'?')))]+=1
for k,n in c.most_common(): print(n,k)
