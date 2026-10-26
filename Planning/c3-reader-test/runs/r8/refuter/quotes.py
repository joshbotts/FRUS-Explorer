import sqlite3, json, re
R8="/Users/jbotts/frus-analysis/c3/runs/r8/"
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ov=open(R8+"overview.md").read()
def N(s): return re.sub(r"[^a-z0-9]","",s.lower())
def segs(q):
    parts=re.split(r"\[\.\.\.\]|\.\.\.|…",q)
    return [N(p) for p in parts if N(p)]
rowcache={}
def row(v,d):
    if (v,d) not in rowcache:
        r=db.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        rowcache[(v,d)]=N("".join(x or "" for x in r)) if r else None
    return rowcache[(v,d)]
def check(q,v,d):
    t=row(v,d)
    if t is None: return ("NO ROW",[])
    off=0; found=[]
    for s in segs(q):
        i=t.find(s,off)
        if i<0: return ("FAIL",found+[(s[:40],-1)])
        found.append((s[:40],i)); off=i+len(s)
    return ("OK",found)
# ---- 1. every straight-double-quoted span in the overview, with the citation that follows it ----
spans=[(m.start(),m.end(),m.group(1)) for m in re.finditer(r'"([^"]+)"',ov)]
print("straight-double-quoted spans in overview:",len(spans))
# citations: URL form, or printed form
url_re=re.compile(r"https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/([a-z_]*d\d+)")
cites=[(m.start(),m.group(1),m.group(2)) for m in url_re.finditer(ov)]
# map printed edition citations (bottom line) -> pairs via memo trace table (section 4)
memo=open(R8+"memo.md").read()
trace={}
for m in re.finditer(r"\| (Q\d+) \| (frus[^,]+), ([a-z_]*d\d+) \| (\d{4}-\d{2}-\d{2}) \|",memo):
    trace[m.group(1)]=(m.group(2),m.group(3))
print("memo Q table entries:",len(trace))
results=[]
for st,en,q in spans:
    # next URL citation after the span
    nxt=[c for c in cites if c[0]>en]
    ctx=ov[en:en+260].replace("\n"," ")
    results.append((st,q,nxt[0] if nxt else None,ctx))
out=open("overview_quotes.tsv","w")
for i,(st,q,c,ctx) in enumerate(results,1):
    print(f"\n[{i}] @{st} len={len(q)} :: {q[:110]!r}")
    print(f"     next-URL-cite: {c[1]+'/'+c[2] if c else None} | after: {ctx[:150]!r}")
    out.write(f"{i}\t{st}\t{q}\t{c[1]+'/'+c[2] if c else ''}\n")
out.close()
# ---- 2. collection excerpts ----
coll=json.load(open(R8+"collection.fruscollection"))
ex=[e for e in coll["entries"] if e["kind"]=="excerpt"]
print("\ncollection excerpts:",len(ex))
for i,e in enumerate(ex,1):
    st,f=check(e["text"],e["volumeId"],e["documentId"])
    print(f"EX{i} {e['volumeId']}/{e['documentId']} {st} segs={len(segs(e['text']))} first_off={f[0][1] if f else None} :: {e['text'][:80]!r}")
