import re,sqlite3,json
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
pairs=[tuple(l.split()) for l in open('pairs.txt')]
bodies={p:c.execute("select body_text,length(body_text) from document_cache where volume_id=? and document_id=?",p).fetchone() for p in pairs}
# whole-text capture check, written to disk
import os
os.makedirs('docs_body',exist_ok=True)
for p,(b,n) in bodies.items():
    open('docs_body/%s__%s.txt'%p,'w').write(b)
    assert len(open('docs_body/%s__%s.txt'%p).read())==n==len(b)
print('captured whole (captured length = length(body_text)):',len(bodies),'documents, total chars',sum(n for b,n in bodies.values()))
ov=open('overview.md').read()
qs=[]
for para in ov.split('\n'):
    parts=para.split('"')
    assert len(parts)%2==1, para[:80]
    qs+= [x for x in parts[1::2] if len(x)>=12]
out=[]
for q in qs:
    hit=[p for p,(b,n) in bodies.items() if q in b]
    out.append((q,hit))
doc=[o for o in out if o[1]]; non=[o for o in out if not o[1]]
print('quoted strings >=12 chars in overview:',len(out),'; found verbatim in a cited document:',len(doc),'; not from a document:',len(non))
for q,h in doc: print('DOC  ',h[0][0]+'/'+h[0][1],'|',q[:70])
for q,h in non: print('OTHER|',q[:100])
# every document cited by URL in overview is in the collection
col=json.load(open('collection.fruscollection'))
inc={(e['volumeId'],e['documentId']) for e in col['entries'] if e['kind']=='document'}
urls=set(re.findall(r'historicaldocuments/([^/\s]+)/(d\d+)',ov))
print('overview cites',len(urls),'distinct documents; all in collection:',urls<=inc, 'missing:',urls-inc)
exc=[e for e in col['entries'] if e['kind']=='excerpt']
bad=[e for e in exc if e['text'] not in bodies[(e['volumeId'],e['documentId'])][0]]
print('collection excerpts',len(exc),'not verbatim:',len(bad))
rows=["vol/doc\tchars_in_body\toffset\texcerpt_length\tSELECT"]
for e in exc:
    b=bodies[(e['volumeId'],e['documentId'])][0]
    rows.append("%s/%s\t%d\t%d\t%d\tSELECT body_text FROM document_cache WHERE volume_id='%s' AND document_id='%s'; (python: excerpt in body_text -> True)"%(e['volumeId'],e['documentId'],len(b),b.find(e['text']),len(e['text']),e['volumeId'],e['documentId']))
open('excerpts_verified.tsv','w').write("\n".join(rows)+"\n")
