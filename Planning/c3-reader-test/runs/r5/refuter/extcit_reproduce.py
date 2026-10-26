# Refuter: the second channel's volume-scoped JSON figures, from external-citation-index.json over MY 38 field volumes; and the DB check of the 8 volumes the JSON does not list.
import json, collections, sqlite3
B='/Applications/FRUS Explorer.app/Contents/Resources/'
e=json.load(open(B+'external-citation-index.json')); a=json.load(open(B+'collection-authority.json')); auth={c['id']:c for c in a['collections']}
vols=sorted({l.split()[0] for l in open('field_pairs.tsv') if l.strip()}); print('field volumes',len(vols))
vi={v:i for i,v in enumerate(e['volumes'])}; si={vi[v] for v in vols if v in vi}
missing=[v for v in vols if v not in vi]; print('in JSON volume list:',len(si),'| not listed:',missing)
ct=collections.Counter()
for t in e['classTargets']:
    n=sum(nn for nn,vv in zip(t['n'],t['v']) if vv in si)
    if n: ct[e['classTargetKeys'][t['k']]]=n
print('central-file classes cited:',len(ct),'citations:',sum(ct.values()),'| top:',ct.most_common(6))
tot=collections.Counter()
for t in e['targets']:
    n=sum(nn for nn,vv in zip(t['n'],t['v']) if vv in si)
    if n: tot[e['targetIds'][t['k']]]=n
print('lot/library targets:',len(tot),'citations:',sum(tot.values()))
for tid,n in tot.most_common(): print('   ',n,tid,'|',(auth.get(tid,{}).get('name') or '')[:90])
# DB side: do the 8 unlisted volumes have external_citations rows at all?
c=sqlite3.connect('file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro',uri=True)
q="select volume_id, count(*) from external_citations where volume_id in (%s) group by 1"%','.join('?'*len(vols))
db=dict(c.execute(q,vols).fetchall())
print('DB external_citations rows per field volume (all docs):',sum(db.values()),'rows in',len(db),'volumes; unlisted volumes with rows:',{v:db.get(v,0) for v in missing})
print('DB rows in listed volumes by anchor:',c.execute("select anchor,count(*) from external_citations where volume_id in (%s) group by 1"%','.join('?'*len(vols)),vols).fetchall())
