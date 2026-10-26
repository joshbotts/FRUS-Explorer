# Glosses document_sources.decimal_class of scope docs with decimal-class-labels.json, ONLY when the document's own date (document_dates.date_iso) falls in a glossable span.
import json, sqlite3, collections, re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
D=json.load(open(R+"decimal-class-labels.json"))
sched={s['id']:s for s in D['schedules']}
spans=[(g['startYear'],g['endYear'],g['scheduleId']) for g in D['coverage']['glossableYears']]
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
db.execute("attach 'file:/Users/jbotts/frus-analysis/c3/runs/r12/scope.db?mode=ro' as s")
rows=db.execute("""select ds.volume_id,ds.document_id,ds.decimal_class,substr(dd.date_iso,1,4)
 from s.scope s join document_cache c on c.volume_id=s.volume_id and c.document_id=s.document_id and c.is_front_matter=0 and c.is_editorial_note=0
 join document_sources ds on ds.volume_id=s.volume_id and ds.document_id=s.document_id
 left join document_dates dd on dd.volume_id=s.volume_id and dd.document_id=s.document_id
 where ds.decimal_class is not null""").fetchall()
print("scope docs with a decimal_class:",len(rows))
cnt=collections.Counter(); nogloss=collections.Counter(); undated=0
for v,d,k,y in rows:
    if not y: undated+=1; continue
    y=int(y); sid=None
    for a,b,i in spans:
        if a<=y<=b: sid=i
    if not sid: nogloss['outside glossable years']+=1; continue
    sc=sched[sid]
    m=re.match(r'(\d)(\d\d)(?:\.(\w+))?',k)
    if not m: nogloss['unparsed']+=1; continue
    cl,ct,sub=m.group(1),m.group(2),m.group(3)
    # 1910-1949: class digit then 2-digit country; later schedules: assume class digit + country (read from schedule's countries)
    cname=sc['countries'].get(ct) or sc['countries'].get(cl+ct)
    clname=sc['classes'].get(cl)
    subj=(sc['subjects'].get(cl,{}) or {}).get((sub or '')[:2]) if sc['subjects'] else None
    cnt[(sid,k.split('/')[0][:6],clname,cname,subj)]+=1
for key,n in cnt.most_common(18): print(n,key)
print("no gloss:",dict(nogloss),"undated",undated)
