# came-from channel for the scope: group document_sources.decimal_class for scope docs, gloss with decimal-class-labels.json ONLY when the document's own date (document_dates.date_iso) is within glossableYears (1910-1963; schedule by year)
import sqlite3,json,collections
j=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/decimal-class-labels.json"))
sched={s['id']:s for s in j['schedules']}
def sch(y):
    for g in j['coverage']['glossableYears']:
        if g['startYear']<=y<=g['endYear']: return sched[g['scheduleId']]
    return None
c=sqlite3.connect('file:/Users/jbotts/frus-analysis/c3/runs/r5/scope.db?mode=ro',uri=True)
c.execute("attach database 'file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro' as m")
rows=c.execute("select s.volume_id,s.document_id,ds.decimal_class,ds.record_group,ds.repository,dd.date_iso from scope s join m.document_sources ds on ds.volume_id=s.volume_id and ds.document_id=s.document_id left join m.document_dates dd on dd.volume_id=s.volume_id and dd.document_id=s.document_id").fetchall()
g=collections.defaultdict(lambda:[0,set(),9999,0])
nodate=0;noglo=0
for v,d,dc,rg,rep,di in rows:
    if not dc: continue
    key=dc
    y=int(di[:4]) if di else None
    e=g[key]; e[0]+=1; e[1].add(v)
    if y: e[2]=min(e[2],y); e[3]=max(e[3],y)
    else: nodate+=1
out=[]
for k,(n,vs,y0,y1) in sorted(g.items(),key=lambda x:-x[1][0]):
    out.append((k,n,len(vs),y0,y1))
print("rows with decimal_class:",sum(x[1] for x in out),"undated:",nodate)
for k,n,nv,y0,y1 in out[:40]:
    parts=k.split('.')
    country=parts[0][:2]; cls=parts[0][2:3]; sub=('.'.join(parts[1:])) if len(parts)>1 else ''
    s=sch(y0) if y0<9999 else None
    gl=None
    if s and sch(y1) is s:
        cn=s['countries'].get(country)
        subj=s['subjects'][0]['1'] if False else None
        subs={}
        for sj in s['subjects']: pass
        gl=cn
    print(k,n,'docs',nv,'vols',y0,y1,'country gloss:',gl)
