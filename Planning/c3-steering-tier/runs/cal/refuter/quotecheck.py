import re, json, sqlite3, sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def segments(q):
    parts=re.split(r'\[\.\.\.\]|\.\.\.|…',q)
    return [norm(p) for p in parts if norm(p)]
_cache={}
def doc_text(v,d):
    if (v,d) not in _cache:
        r=db.execute("select coalesce(header,''),coalesce(dateline,''),coalesce(source_note,''),coalesce(body_text,'') from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
        _cache[(v,d)]=None if r is None else norm(''.join(r))
    return _cache[(v,d)]
def check(q,v,d):
    t=doc_text(v,d)
    if t is None: return ('NO SUCH ROW',None)
    segs=segments(q); pos=0; offs=[]
    for s in segs:
        i=t.find(s,pos)
        if i<0: return ('FAIL',offs+[(s[:40],-1)])
        offs.append(i); pos=i+len(s)
    return ('OK',offs)
# ---- overview spans
txt=open('../overview.md',encoding='utf-8').read()
urls=[(m.start(),m.group(1),m.group(2)) for m in re.finditer(r'historicaldocuments/([^/\s)]+)/([A-Za-z0-9]+)',txt)]
def pair_after(pos):
    for p,v,d in urls:
        if p>pos: return (v,d)
    return None
spans=[(m.start(),m.end(),m.group(1)) for m in re.finditer(r'"([^"]+)"',txt)]
spans+=[(m.start(),m.end(),m.group(1)) for m in re.finditer(r'“([^”]+)”',txt)]
spans.sort()
print("=== OVERVIEW double-quoted spans:",len(spans))
fab=0; ok=0
rows=[]
for s,e,q in spans:
    if q.startswith('Cuba, national security and prosperity'):
        print(f"  [skip: collection name] {q[:60]}"); continue
    pr=pair_after(e)
    st,offs=check(q,*pr)
    rows.append((q,pr,st,offs))
    print(f"  {st:4} {pr[0]}/{pr[1]:6} | {q[:95]}")
    if st=='OK': ok+=1
    else: fab+=1
print("overview spans checked:",ok+fab,"OK:",ok,"FAIL:",fab)
# single-quoted spans (terms); report and test any that read as document quotations
print("=== OVERVIEW single-quoted spans (listed; term-like ones are not quotations):")
for m in re.finditer(r"(?<![A-Za-z])'([^']{3,80})'(?![A-Za-z])",txt):
    print("   ",repr(m.group(1)))
# 'strategic concept' in the section-4 heading -> frus1952-54v04/d342
print("  heading span 'strategic concept' vs frus1952-54v04/d342:",check("strategic concept","frus1952-54v04","d342")[0])
# ---- collection excerpts
c=json.load(open('../collection.fruscollection'))
exc=[e for e in c['entries'] if e['kind']=='excerpt']
print("=== COLLECTION excerpts:",len(exc))
eok=0
for e in exc:
    st,offs=check(e['text'],e['volumeId'],e['documentId'])
    if st=='OK': eok+=1
    print(f"  {st:4} {e['volumeId']}/{e['documentId']:6} | {e['text'][:80]}")
print("excerpts OK:",eok,"of",len(exc))
# ---- which pair does each excerpt's document entry precede? (excerpt must follow its own document entry)
prev=None; mis=0
for e in c['entries']:
    if e['kind']=='document': prev=(e['volumeId'],e['documentId'])
    elif e['kind']=='excerpt' and (e['volumeId'],e['documentId'])!=prev: mis+=1; print("  excerpt not under its own document:",e['volumeId'],e['documentId'],'after',prev)
print("excerpts placed under another document's entry:",mis)
# ---- cited URLs vs collection
pairs={(e['volumeId'],e['documentId']) for e in c['entries'] if e['kind']=='document'}
cited=[]
for p,v,d in urls:
    if (v,d) not in cited: cited.append((v,d))
print("=== cited URL pairs in overview:",len(cited))
print("  not in collection:",[x for x in cited if x not in pairs])
print("  in collection but not cited:",sorted(pairs-set(cited)))
json.dump({'cited':cited},open('cited_pairs.json','w'))
