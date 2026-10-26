# Refuter: rebuild the field from volume_structures for the 62 (volume, sectionId) pairs in scope_sections.tsv, independently of struct.db/scope.db.
import sqlite3, json
R='/Users/jbotts/frus-analysis/c3/runs/r5/'
c=sqlite3.connect('file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro',uri=True)
secs=[l.rstrip('\n').split('\t') for l in open(R+'scope_sections.tsv',encoding='utf-8') if l.strip()]
print('sections listed:',len(secs),'distinct (vol,sec):',len({(a,b) for a,b,*_ in secs}))
def walk(node,path):
    t=' '.join((node.get('title') or '').split()); p=path+[t] if t else path
    yield node,p
    for s in node.get('subsections',[]) or []: yield from walk(s,p)
cache={}
field=[]; appendix=[]
for v,sid,*_ in secs:
    if v not in cache: cache[v]=json.loads(c.execute("select structure_json from volume_structures where volume_id=?",(v,)).fetchone()[0])
    hit=[(n,p) for sec in cache[v]['sections'] for n,p in walk(sec,[]) if n.get('sectionId')==sid]
    assert len(hit)==1,(v,sid,len(hit))
    n,p=hit[0]; ids=n.get('documentIds') or []
    kept=[]
    for d in ids:
        r=c.execute("select is_front_matter,is_editorial_note from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
        assert r is not None,(v,d)
        if not r[0] and not r[1]: kept.append(d)
    appendix.append((v,sid,len(ids),len(kept),' > '.join(p)[:100]))
    field+= [(v,d) for d in kept]
print('field docs (my rebuild):',len(field),'distinct pairs:',len(set(field)),'volumes:',len({v for v,_ in field}))
scope=set(tuple(l.split()) for l in open(R+'scope_docs.tsv') if l.strip())
print('scope_docs.tsv:',len(scope),'volumes:',len({v for v,_ in scope}))
print('rebuild == scope_docs.tsv:', set(field)==scope, '| only mine:',sorted(set(field)-scope)[:5],'| only theirs:',sorted(scope-set(field))[:5])
vols=sorted({v for v,_ in field})
q="select count(*) from document_cache where is_front_matter=0 and is_editorial_note=0 and volume_id in (%s)"%','.join('?'*len(vols))
print('38-volume non-apparatus denominator:',c.execute(q,vols).fetchone()[0])
print('whole-series non-apparatus:',c.execute("select count(*), sum(is_front_matter=0 and is_editorial_note=0) from document_cache").fetchone())
# date span of the field
dates=[]
for v,d in field:
    r=c.execute("select date_iso from document_dates where volume_id=? and document_id=?",(v,d)).fetchone()
    dates.append(r[0] if r else None)
nn=[x for x in dates if x]
print('field dated:',len(nn),'of',len(field),'min',min(nn),'max',max(nn))
# Appendix A rows where section count != field count
for row in appendix:
    if row[2]!=row[3]: print('  apparatus inside section:',row[:4])
open('field_pairs.tsv','w').write('\n'.join(f'{v}\t{d}' for v,d in field)+'\n')
