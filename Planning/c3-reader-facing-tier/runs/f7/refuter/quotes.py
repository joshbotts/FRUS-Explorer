import re,sqlite3,json,sys
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
db=sqlite3.connect(f"file:{DB}?mode=ro",uri=True)
RUN="/Users/jbotts/frus-analysis/c3f/runs/f7/"
ov=open(RUN+"overview.md",encoding="utf-8").read()
coll=json.load(open(RUN+"collection.fruscollection"))
docs=[(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"]
exc=[(e["volumeId"],e["documentId"],e["text"]) for e in coll["entries"] if e["kind"]=="excerpt"]
def norm(s): return re.sub(r"[^a-z0-9]","",s.lower())
def segs(q):
    parts=re.split(r"…|\.\.\.|\[\.\.\.\]",q)
    return [norm(p) for p in parts if norm(p)]
rowcache={}
def rowtext(v,d):
    if (v,d) not in rowcache:
        r=db.execute("select header,dateline,source_note,body_text,document_number,is_front_matter,is_editorial_note from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
        rowcache[(v,d)]=r
    return rowcache[(v,d)]
def check(q,v,d):
    r=rowtext(v,d)
    if r is None: return False,"ROW ABSENT"
    t=norm((r[0] or "")+(r[1] or "")+(r[2] or "")+(r[3] or ""))
    pos=0
    for s in segs(q):
        i=t.find(s,pos)
        if i<0: return False,"segment not found: "+s[:60]
        pos=i+len(s)
    return True,"ok"
print("=== A. COLLECTION EXCERPTS (45) against their own pair")
bad=0
for v,d,t in exc:
    ok,msg=check(t,v,d)
    if not ok: bad+=1; print("  FAIL",v,d,msg,"|",t[:80])
print("  excerpts:",len(exc),"pass:",len(exc)-bad,"fail:",bad)
print()
print("=== B. OVERVIEW quoted spans")
spans=[(m.start(),m.end(),m.group(1)) for m in re.finditer(r'"([^"\n]+)"',ov)]
urls=[(m.start(),m.group(1),m.group(2)) for m in re.finditer(r"historicaldocuments/(frus[\w\-]+)/(d\w+)",ov)]
def para_bounds(pos):
    a=ov.rfind("\n\n",0,pos); b=ov.find("\n\n",pos)
    return (a if a>=0 else 0),(b if b>=0 else len(ov))
print("spans:",len(spans))
for i,(a,b,q) in enumerate(spans):
    found=[f"{v}/{d}" for v,d in docs if check(q,v,d)[0]]
    pa,pb=para_bounds(a)
    nexturls=[(u[1]+"/"+u[2]) for u in urls if a<u[0]<=pb]
    # the first URL(s) after the span inside the same parenthetical/sentence: take URLs up to the first ')' after the span
    close=ov.find(")",b); 
    near=[(u[1]+"/"+u[2]) for u in urls if b<=u[0]<=(close if close>0 else pb)]
    print(f"[{i}] \"{q[:90]}\"\n     found_in={found}\n     near_urls={near}  para_urls_after={nexturls[:4]}")
