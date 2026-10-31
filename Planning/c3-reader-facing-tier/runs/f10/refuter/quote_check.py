import sqlite3,json,re,sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def doc_text(v,d):
    r=db.execute("select header,dateline,source_note,body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    if not r: return None
    return norm((r[0] or '')+(r[1] or '')+(r[2] or '')+(r[3] or ''))
def check(q,v,d):
    t=doc_text(v,d)
    if t is None: return ('NO ROW',None)
    segs=[s for s in re.split(r'…|\.\.\.|\[\.\.\.\]',q) if norm(s)]
    pos=0; ok=True
    for s in segs:
        n=norm(s); i=t.find(n,pos)
        if i<0: ok=False; break
        pos=i+len(n)
    return ('FOUND' if ok else 'NOT FOUND', len(segs))
# 1. collection excerpts
c=json.load(open('collection.fruscollection'))
exc=[e for e in c['entries'] if e['kind']=='excerpt']
print("=== COLLECTION EXCERPTS:",len(exc))
bad=0
for i,e in enumerate(exc,1):
    r=check(e['text'],e['volumeId'],e['documentId'])
    if r[0]!='FOUND': bad+=1
    print(f"E{i:02d} {e['volumeId']}/{e['documentId']} {r[0]} segs={r[1]} :: {e['text'][:70]}")
print("excerpts not found:",bad)
# 2. overview quotations: every passage inside curly or straight double quotes, each assigned to the citation that follows it in the same sentence/paragraph.
ov=open('overview.md').read()
# split into paragraphs
paras=[p for p in ov.split('\n') if p.strip()]
quotes=[]
for p in paras:
    # find quoted passages
    for m in re.finditer(r'[“"]([^”"]{3,}?)[”"]',p):
        q=m.group(1)
        # the citation: the nearest URL after the quote in the paragraph; fall back to nearest before
        after=re.search(r'historicaldocuments/(frus[^/]+)/d(\d+)',p[m.end():])
        before=[x for x in re.finditer(r'historicaldocuments/(frus[^/]+)/d(\d+)',p[:m.start()])]
        cite=(after.group(1),'d'+after.group(2)) if after else ((before[-1].group(1),'d'+before[-1].group(2)) if before else None)
        quotes.append((q,cite,p[:40]))
print("\n=== OVERVIEW QUOTED PASSAGES:",len(quotes))
for i,(q,cite,ctx) in enumerate(quotes,1):
    if cite:
        r=check(q,*cite)
        print(f"O{i:02d} {cite[0]}/{cite[1]} {r[0]} :: {q[:80]}")
    else:
        print(f"O{i:02d} NO-CITE :: {q[:80]}  [para: {ctx}]")
