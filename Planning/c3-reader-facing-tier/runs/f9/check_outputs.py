# checks: collection contract; excerpts exact in body_text (SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?);
# overview cited pairs == collection docs; every "..." span in overview is a substring of a collection document's body_text (allow-list for non-document strings)
import json,re,sqlite3
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
col=json.load(open('collection.fruscollection'))
assert col['format']=='fruscollection' and col['formatVersion']==2 and col['minimumReaderVersion']==1
assert set(col['composition'])=={"defaultBodyDepth","footnoteStyle","includeSourceNote","tocStyle","applyHighlights","includeNotes","includeWordCloud"}
docs=[];exc=[]
for e in col['entries']:
    if e['kind'] in('document','excerpt'): assert e.get('volumeId') and e.get('documentId'),e
    if e['kind']=='document': docs.append((e['volumeId'],e['documentId'])); assert e['notes'][0].startswith('Agent finding, run f9, 2026-10-31:')
    if e['kind']=='excerpt': exc.append(e)
assert len(docs)==len(set(docs)); assert not any('Ed2' in v for v,d in docs)
body={}
for v,d in docs:
    r=c.execute("SELECT body_text,is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone(); assert r and r[1]==0 and r[2]==0; body[(v,d)]=r[0]
for e in exc:
    k=(e['volumeId'],e['documentId']); assert k in body,k; assert e['text'] in body[k],e['text']
print('collection OK: docs',len(docs),'excerpts',len(exc),'last entry',col['entries'][-1])
assert col['entries'][-1]=={"kind":"generated","generatedBlockType":"archivalSources"}
ov=open('overview.md').read()
cited=set(re.findall(r'historicaldocuments/([^/\s)]+)/(d\w+)',ov))
print('overview URL pairs',len(cited),'missing from collection',cited-set(docs),'collection docs not cited by URL',set(docs)-cited)
allow={'Soft power','soft','Department of State','Oriental','Asian','USI','saturated','effective','Oriental mind'}
alltext=' '.join(body.values())
bad=[]
for q in re.findall(r'"([^"]+)"',ov):
    if q in allow: continue
    if q not in alltext: bad.append(q)
print('overview quoted spans not found verbatim in collection bodies:',bad)
for q in ['saturated','effective']: print(q, 'in collection bodies:', q in alltext)
