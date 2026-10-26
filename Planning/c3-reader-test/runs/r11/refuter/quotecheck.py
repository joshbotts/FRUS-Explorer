import sqlite3,re,json
RUN="/Users/jbotts/frus-analysis/c3/runs/r11/"
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def segs(s): return [x for x in re.split(r'\[\.\.\.\]|\.\.\.|…',s) if norm(x)]
def check(txt,v,d):
    r=con.execute("SELECT header, coalesce(dateline,''), coalesce(source_note,''), body_text, document_number FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: return ("NO SUCH ROW",None)
    doc=norm(r[0]+r[1]+r[2]+r[3]); pos=0; ok=True
    for sg in segs(txt):
        i=doc.find(norm(sg),pos)
        if i<0: ok=False; break
        pos=i+len(norm(sg))
    return ("FOUND" if ok else "NOT FOUND", r[4])
t=open(RUN+"overview.md",encoding='utf-8').read()
qs=[(m.start(),m.group(1)) for m in re.finditer(r'"([^"]+)"',t)]
urls=[(m.start(),m.group(1),m.group(2)) for m in re.finditer(r'historicaldocuments/([^/\s)]+)/(d\d+)',t)]
memo=json.load(open(RUN+"quotes.json"))
print("== OVERVIEW quotations (quote-delimited strings of 30+ chars or 'an established fact') -> pair of the nearest FOLLOWING url")
n=0; found=0
for pos,qtxt in qs:
    if len(qtxt)<30 and qtxt!='an established fact': continue
    if qtxt.startswith('Recognizing governments'): continue  # the collection's name
    n+=1
    nxt=[u for u in urls if u[0]>pos]
    v,d=nxt[0][1],nxt[0][2]
    res,dn=check(qtxt,v,d)
    mids=[m[0] for m in memo if norm(m[3]).find(norm(qtxt))>=0 or norm(qtxt).find(norm(m[3]))>=0]
    mpair=[(m[1],m[2]) for m in memo if m[0] in mids]
    agree=all(p==(v,d) for p in mpair) if mpair else None
    if res=="FOUND": found+=1
    print("[%2d] %-9s pair=%s/%s docnum=%s memo=%s memo-pair-agrees=%s :: %s"%(n,res,v,d,dn,mids,agree,qtxt[:60]))
print("overview quotations:",n,"found in cited pair:",found)
print()
print("== COLLECTION excerpts")
c=json.load(open(RUN+"collection.fruscollection"))
m=0; f=0
for e in c["entries"]:
    if e["kind"]!="excerpt": continue
    m+=1; res,dn=check(e["text"],e["volumeId"],e["documentId"])
    if res=="FOUND": f+=1
    print("%-9s %s/%s :: %s"%(res,e["volumeId"],e["documentId"],e["text"][:60]))
print("excerpts:",m,"found:",f)
