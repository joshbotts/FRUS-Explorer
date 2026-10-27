import sqlite3, re, json, sys
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
db=sqlite3.connect(DB,uri=True)
def norm(s): return re.sub(r'[^a-z0-9]','',(s or '').lower())
def doc_text(v,d):
    r=db.execute("select header,dateline,source_note,body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    if r is None: return None
    return norm((r[0] or '')+(r[1] or '')+(r[2] or '')+(r[3] or ''))
def segments(q):
    parts=re.split(r'\[\.\.\.\]|\.\.\.|…',q)
    return [norm(p) for p in parts if norm(p)]
def check(q,v,d):
    t=doc_text(v,d)
    if t is None: return ('NO SUCH ROW',[])
    pos=0; offs=[]
    for seg in segments(q):
        i=t.find(seg,pos)
        if i<0: return ('FAIL',offs+[(seg[:40],-1)])
        offs.append((seg[:40],i)); pos=i+len(seg)
    return ('OK',offs)
# --- overview double-quoted spans with the next URL after each
txt=open('/Users/jbotts/frus-analysis/c3v/runs/v3/overview.md',encoding='utf-8').read()
spans=[(m.start(),m.group(1)) for m in re.finditer(r'"([^"]+)"',txt)]
urls=[(m.start(),m.group(1),m.group(2)) for m in re.finditer(r'historicaldocuments/([^/\s)]+)/([A-Za-z0-9]+)',txt)]
print("overview double-quoted spans:",len(spans))
res=[]
for pos,s in spans:
    nxt=[u for u in urls if u[0]>pos]
    v,d=(nxt[0][1],nxt[0][2]) if nxt else (None,None)
    status,offs=check(s,v,d) if v else ('NO URL',[])
    res.append((s,v,d,status))
    print(f"[{status}] {v}/{d} :: {s[:90]}")
# single-quoted phrases in the overview that read as document quotations
for m in re.finditer(r"'([^']{5,})'",txt):
    s=m.group(1)
    nxt=[u for u in urls if u[0]>m.start()]
    v,d=(nxt[0][1],nxt[0][2]) if nxt else (None,None)
    st,_=check(s,v,d) if v else ('NO URL',[])
    print(f"  single-quoted: [{st}] {v}/{d} :: {s[:80]}")
# --- collection excerpts
col=json.load(open('/Users/jbotts/frus-analysis/c3v/runs/v3/collection.fruscollection'))
n=0; bad=0
for e in col['entries']:
    if e['kind']=='excerpt':
        n+=1
        st,offs=check(e['text'],e['volumeId'],e['documentId'])
        if st!='OK': bad+=1
        print(f"excerpt [{st}] {e['volumeId']}/{e['documentId']} :: {e['text'][:80]}")
print("excerpts:",n,"failing:",bad)
# notes' single-quoted phrases
for e in col['entries']:
    if e['kind'] in ('document',) and e.get('notes'):
        for note in e['notes']:
            for m in re.finditer(r"'([^']{5,})'",note):
                st,_=check(m.group(1),e['volumeId'],e['documentId'])
                print(f"  note-quote [{st}] {e['volumeId']}/{e['documentId']} :: {m.group(1)[:70]}")
    if e['kind']=='prose':
        for m in re.finditer(r"'([^']{5,})'",e['text']):
            print(f"  prose-quote (no pair) :: {m.group(1)[:70]}")
