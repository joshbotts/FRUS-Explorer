import json, re, sqlite3, sys
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RUN="/Users/jbotts/frus-analysis/c3/runs/r3"
con=sqlite3.connect(f"file:{DB}?mode=ro", uri=True)

def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def segments(q):
    parts=re.split(r'\[\.\.\.\]|\.\.\.|…', q)
    return [norm(p) for p in parts if norm(p)]
def rowtext(v,d):
    r=con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if r is None: return None
    return ''.join(x or '' for x in r)
def check(q,v,d):
    t=rowtext(v,d)
    if t is None: return ('NO_ROW',[])
    nt=norm(t); pos=0; offs=[]
    for seg in segments(q):
        i=nt.find(seg,pos)
        if i<0: return ('FAIL',offs+[(seg[:40],-1)])
        offs.append((seg[:40],i)); pos=i+len(seg)
    return ('OK',offs)

# 1. overview quotations
ov=open(f"{RUN}/overview.md",encoding='utf-8').read()
# find quoted passages: straight "..." and curly “...”
quotes=[]
for m in re.finditer(r'"([^"]+)"|“([^”]+)”', ov):
    q=m.group(1) or m.group(2)
    # the nearest following history.state.gov URL within 600 chars
    tail=ov[m.end():m.end()+700]
    u=re.search(r'https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/([A-Za-z0-9_\-]+)', tail)
    quotes.append((m.start(), q, (u.group(1),u.group(2)) if u else None))
print("OVERVIEW QUOTED STRINGS:", len(quotes))
for i,(pos,q,pair) in enumerate(quotes,1):
    print(f"{i:2d}. @{pos} pair={pair} len={len(q)} :: {q[:110]}")
json.dump([(p,q,pr) for p,q,pr in quotes], open(f"{RUN}/refuter/overview_quotes.json","w"), ensure_ascii=False, indent=1)

# 2. collection excerpts
c=json.load(open(f"{RUN}/collection.fruscollection"))
ex=[e for e in c['entries'] if e.get('kind')=='excerpt']
print("\nCOLLECTION EXCERPTS:", len(ex))
fails=0
for e in ex:
    st,offs=check(e['text'],e['volumeId'],e['documentId'])
    if st!='OK': fails+=1
    print(f"{st:6s} {e['volumeId']}/{e['documentId']} off={offs[-1][1] if offs else None} len={len(e['text'])} :: {e['text'][:80]}")
print("excerpt failures:",fails)
