import json, re, sqlite3, sys
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con=sqlite3.connect(f"file:{DB}?mode=ro",uri=True)
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def split_ell(q):
    return [p for p in re.split(r'\[\.\.\.\]|\.\.\.|…',q) if norm(p)]
cache={}
def doc_text(vol,did):
    if (vol,did) not in cache:
        r=con.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(vol,did)).fetchone()
        cache[(vol,did)] = None if r is None else norm((r[0] or '')+(r[1] or '')+(r[2] or '')+(r[3] or ''))
    return cache[(vol,did)]
def check(q,vol,did):
    t=doc_text(vol,did)
    if t is None: return ("NO SUCH ROW",[])
    pos=0; offs=[]
    for seg in split_ell(q):
        i=t.find(norm(seg),pos)
        if i<0: return ("FAIL",offs+[(seg[:40],-1)])
        offs.append((seg[:40],i)); pos=i+len(norm(seg))
    return ("OK",offs)
ov=open('/Users/jbotts/frus-analysis/c3/runs/r12/overview.md',encoding='utf-8').read().split('\n')
# 1) block quotes
n=0; results=[]
for ln,line in enumerate(ov,1):
    if line.startswith('> “'):
        m=re.match(r'> “(.*)”—(.*?), https://history\.state\.gov/historicaldocuments/([A-Za-z0-9.-]+)/(d\d+)\s*$',line)
        if not m: print("UNPARSED BLOCK QUOTE line",ln,line[:80]); continue
        q,cit,vol,did=m.groups(); n+=1
        st,offs=check(q,vol,did)
        results.append(("block",ln,vol,did,st,q))
        print(f"BLOCK L{ln} {vol}/{did} {st} {offs[0][1] if offs else ''} | {q[:70]}…")
# 2) inline quotes (not in block-quote lines)
for ln,line in enumerate(ov,1):
    if line.startswith('> '): continue
    for m in re.finditer(r'“([^”]+)”',line):
        q=m.group(1)
        # find the nearest following URL on the same line within the same parenthesis
        tail=line[m.end():]
        um=re.search(r'https://history\.state\.gov/historicaldocuments/([A-Za-z0-9.-]+)/(d\d+)',tail)
        pair=(um.group(1),um.group(2)) if um else None
        results.append(("inline",ln,pair,q))
        print(f"INLINE L{ln} pair={pair} | {q!r}")
# 3) collection excerpts
c=json.load(open('/Users/jbotts/frus-analysis/c3/runs/r12/collection.fruscollection'))
ex=[e for e in c['entries'] if e['kind']=='excerpt']
okc=0
for i,e in enumerate(ex,1):
    st,offs=check(e['text'],e['volumeId'],e['documentId'])
    okc+= st=="OK"
    print(f"EXCERPT {i:02d} {e['volumeId']}/{e['documentId']} {st} off={offs[0][1] if offs else ''} | {e['text'][:60]}…")
print("excerpts OK:",okc,"of",len(ex))
# 4) are the overview's block quotes identical to the excerpts (text + pair)?
exset={(e['volumeId'],e['documentId'],e['text']) for e in ex}
bl={(r[2],r[3],r[5]) for r in results if r[0]=="block"}
print("block quotes:",len(bl),"in excerpt set:",len(bl&exset),"block not in excerpts:",bl-exset)
print("excerpts not among block quotes:",[ (v,d,t[:40]) for v,d,t in exset-bl])
