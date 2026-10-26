# Refuter: the argument set (56 docs / 31 volumes) from the COLLECTION itself, its date span, and the overview's 48 cited pairs vs the collection.
import sqlite3, json, re
R='/Users/jbotts/frus-analysis/c3/runs/r5/'
c=sqlite3.connect('file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro',uri=True)
coll=json.load(open(R+'collection.fruscollection',encoding='utf-8'))
docs=[(e['volumeId'],e['documentId']) for e in coll['entries'] if e['kind']=='document']
print('collection documents:',len(docs),'distinct:',len(set(docs)),'volumes:',len({v for v,_ in docs}))
print('volumes:',sorted({v for v,_ in docs}))
bad=[]; dates=[]; dl=[]
for v,d in docs:
    r=c.execute("select is_front_matter,is_editorial_note,dateline from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    if r is None or r[0] or r[1]: bad.append((v,d,r))
    dl.append((v,d,r[2] if r else None))
    r2=c.execute("select date_iso from document_dates where volume_id=? and document_id=?",(v,d)).fetchone()
    dates.append((r2[0] if r2 else None,v,d))
print('missing/apparatus:',bad)
nn=sorted(x for x in dates if x[0])
print('dated',len(nn),'of',len(docs),'| earliest',nn[0],'| latest',nn[-1])
print('undated:',[x for x in dates if not x[0]])
# field membership of the argument docs
field=set(tuple(l.split()) for l in open('field_pairs.tsv') if l.strip())
inf=sum(1 for p in docs if p in field); print('argument docs inside the field:',inf,'outside:',len(docs)-inf)
# overview cited pairs
t=open(R+'overview.md',encoding='utf-8').read()
cited=sorted(set(re.findall(r'https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)',t)))
print('overview cites',len(cited),'distinct pairs; not in collection:',[p for p in cited if p not in set(docs)])
print('collection docs not cited in overview:',len([p for p in docs if p not in set(cited)]), sorted(p for p in docs if p not in set(cited)))
# the two post-1950 "eleven cases" and the 18 quoted docs
ex=[(e['volumeId'],e['documentId']) for e in coll['entries'] if e['kind']=='excerpt']
print('excerpt entries',len(ex),'distinct docs',len(set(ex)),'all excerpt docs in collection:',all(p in set(docs) for p in ex))
