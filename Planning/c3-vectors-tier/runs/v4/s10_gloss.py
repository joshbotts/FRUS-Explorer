# Gloss top decimal classes in W came-from channel, ONLY with the schedule governing each document's own date (coverage.glossableYears).
import json,sqlite3,collections
R="/Applications/FRUS Explorer.app/Contents/Resources/"
d=json.load(open(R+'decimal-class-labels.json'))
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
iso={tuple(l.split('\t')[:2]):l.split('\t')[2] for l in open('cuba_set.tsv')}
def sched(y):
    for s in d['schedules']:
        if s['startYear']<=y<=s['endYear']: return s
cnt=collections.Counter()
SQL="SELECT volume_id,document_id,decimal_class FROM document_sources WHERE citation_era='decimal' AND decimal_class IS NOT NULL"
for v,dd,dc in c.execute(SQL):
    k=(v,dd)
    if k not in iso or not iso[k]: continue
    y=int(iso[k][:4]); s=sched(y)
    key=dc.split('/')[0]
    cnt[(s['id'] if s else 'no-gloss', key[:6])]+=1
print("SQL:",SQL)
for (sid,key),n in cnt.most_common(14):
    s=[x for x in d['schedules'] if x['id']==sid]
    g=''
    if s:
        s=s[0]; cl=key[0]; co=key[1:3]; sub=key.split('.')[1] if '.' in key else ''
        g="%s | country %s=%s | subject %s=%s"%(s['classes'].get(cl),co,s['countries'].get(co),sub,s['subjects'].get(sub) if isinstance(s['subjects'].get(sub),str) else json.dumps(s['subjects'].get(sub))[:80])
    print(sid,key,n,g)
