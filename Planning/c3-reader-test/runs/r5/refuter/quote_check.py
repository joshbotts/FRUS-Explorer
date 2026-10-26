# Refuter: the guide's quotation check over every overview quotation and every collection excerpt, against the exact pair.
import sqlite3, json, re
R='/Users/jbotts/frus-analysis/c3/runs/r5/'
c=sqlite3.connect('file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro',uri=True)
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def segs(q): return [s for s in re.split(r'…|\.\.\.|\[\.\.\.\]',q) if norm(s)]
def doc_text(v,d):
    r=c.execute("select header,dateline,source_note,body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    return None if r is None else norm(''.join(x or '' for x in r))
def check(q,v,d):
    t=doc_text(v,d)
    if t is None: return 'NO SUCH PAIR'
    pos=0
    for s in segs(q):
        i=t.find(norm(s),pos)
        if i<0: return 'FAIL at segment %r'%s[:60]
        pos=i+len(norm(s))
    return 'OK'
ov=open(R+'overview.md',encoding='utf-8').read()
# bullets: “quote” — Title, Document N, URL
bul=re.findall(r'^- “(.+?)” — (.+?), Document (\d+), https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)\s*$',ov,flags=re.M)
print('overview bullet quotations:',len(bul))
for q,title,num,v,d in bul:
    dn=c.execute("select document_number from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    print(f'  {v}/{d} docnum={dn[0] if dn else None} cited=Document {num} | {check(q,v,d)} | {q[:50]}...')
# the inline short quotation on L54
m=re.search(r'Stimson wrote in January 1932 that Martínez could "(under no circumstances)" be recognized \((.+?), Document (\d+), https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)\)',ov)
if m: print('inline "under no circumstances":',m.group(4),m.group(5),check(m.group(1),m.group(4),m.group(5)))
# other quoted spans (not document quotations) listed for the record
others=[s for s in re.findall(r'[“"]([^”"]+)[”"]',ov) if s not in {b[0] for b in bul} and s!='under no circumstances']
print('other quoted spans (not attributed to a document):',others)
coll=json.load(open(R+'collection.fruscollection',encoding='utf-8'))
ex=[e for e in coll['entries'] if e['kind']=='excerpt']
print('collection excerpts:',len(ex))
res=[(e['volumeId'],e['documentId'],check(e['text'],e['volumeId'],e['documentId'])) for e in ex]
for r in res: print('  ',r)
print('excerpt texts == overview bullet texts:', {e['text'] for e in ex}=={b[0] for b in bul})
# does each excerpt's pair match the overview's pair for the same text?
ovmap={b[0]:(b[3],b[4]) for b in bul}
print('excerpt pair mismatches vs overview:',[(e['volumeId'],e['documentId'],ovmap.get(e['text'])) for e in ex if ovmap.get(e['text'])!=(e['volumeId'],e['documentId'])])
