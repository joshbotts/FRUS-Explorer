import re, json, sqlite3, sys
R="/Users/jbotts/frus-analysis/c3s/runs/s9"
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con=sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def segs(q):
    parts=re.split(r'\[\.\.\.\]|\.\.\.|…', q)
    return [norm(p) for p in parts if norm(p)]
texts={}
def text(v,d):
    if (v,d) not in texts:
        r=con.execute("SELECT header, IFNULL(dateline,''), IFNULL(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        texts[(v,d)] = norm("".join(r)) if r else None
    return texts[(v,d)]
def check(q,v,d):
    t=text(v,d)
    if t is None: return False, "pair not in document_cache"
    pos=0; 
    for s in segs(q):
        i=t.find(s,pos)
        if i<0: return False, f"segment not found at increasing offset: {s[:60]}"
        pos=i+len(s)
    return True, "ok"
coll=json.load(open(R+"/collection.fruscollection"))
pairs=[(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"]
s=open(R+"/overview.md").read()
# straight double-quote spans, paired sequentially
spans=[]
for m in re.finditer(r'"([^"]*)"', s):
    spans.append((m.start(), m.end(), m.group(1)))
print("=== OVERVIEW straight-quoted spans:", len(spans))
n=0
results=[]
for st,en,q in spans:
    n+=1
    # next URL after the span
    m=re.search(r'historicaldocuments/([^/\s)]+)/(d\d+)', s[en:])
    cited=(m.group(1),m.group(2)) if m else None
    ok,why = check(q,*cited) if cited else (None,"no following URL")
    others=[p for p in pairs if p!=cited and check(q,*p)[0]]
    results.append((n,q,cited,ok,why,others))
    print(f"[{n}] cited={cited} ok={ok} ({why}); also-in={others}\n     {q[:110]!r}")
print("\n=== COLLECTION excerpts")
k=0
for e in coll["entries"]:
    if e["kind"]=="excerpt":
        k+=1
        ok,why=check(e["text"],e["volumeId"],e["documentId"])
        print(f"[E{k}] {e['volumeId']}/{e['documentId']} ok={ok} ({why}) {e['text'][:80]!r}")
