import sqlite3, json, re
R8="/Users/jbotts/frus-analysis/c3/runs/r8/"
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ov=open(R8+"overview.md").read()
def N(s): return re.sub(r"[^a-z0-9]","",s.lower())
def segs(q): return [N(p) for p in re.split(r"\[\.\.\.\]|\.\.\.|…",q) if N(p)]
cache={}
def row(v,d):
    if (v,d) not in cache:
        r=db.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        cache[(v,d)]=N("".join(x or "" for x in r)) if r else None
    return cache[(v,d)]
def check(q,v,d):
    t=row(v,d)
    if t is None: return "NO ROW",[]
    off=0; offs=[]
    for s in segs(q):
        i=t.find(s,off)
        if i<0: return "FAIL",offs+[-1]
        offs.append(i); off=i+len(s)
    return "OK",offs
spans=[(m.start(),m.group(1)) for m in re.finditer(r'"([^"]+)"',ov)]
url_re=re.compile(r"https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/([a-z_]*d\d+)")
cites=[(m.start(),m.group(1),m.group(2)) for m in url_re.finditer(ov)]
# span 1 is in the bottom line and is credited to a printed group citation; resolve that group by hand through the manifest titles already checked
group1=[("frus1913","d7"),("frus1913","d1028"),("frus1917","d379"),("frus1921v01","d238")]
out=open("overview_quote_checks.tsv","w"); out.write("n\tpair\tstatus\toffsets\tsegments\tquote\n")
doc_spans=[1]+list(range(4,38))
nfab=0; nmis=0
for n,(st,q) in enumerate(spans,1):
    if n not in doc_spans and n not in (2,3,26): continue
    if n==1:
        res=[(v,d,check(q,v,d)) for v,d in group1]
        print(f"[1] group citation; per document: {[(v,d,r[0]) for v,d,r in res]} :: {q!r}")
        out.write(f"1\t{';'.join(v+'/'+d for v,d in group1)}\t{[r[0] for _,_,r in res]}\t\t{len(segs(q))}\t{q}\n"); continue
    nxt=[c for c in cites if c[0]>st][0]
    v,d=nxt[1],nxt[2]
    stt,offs=check(q,v,d)
    tag="" if n not in (2,3,26) else "  (term, not a document quotation)"
    print(f"[{n}] {v}/{d} {stt} offs={offs} segs={len(segs(q))}{tag} :: {q[:90]!r}")
    out.write(f"{n}\t{v}/{d}\t{stt}\t{offs}\t{len(segs(q))}\t{q}\n")
    if stt!="OK" and n in doc_spans:
        # where else does it occur? search the 52 read documents and the whole corpus by FTS on the first 6 words
        words=re.findall(r"[A-Za-z]+",q)[:6]
        hits=db.execute("SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? LIMIT 10",('"'+" ".join(words)+'"',)).fetchall()
        found=[(hv,hd) for hv,hd in hits if check(q,hv,hd)[0]=="OK"]
        print("      found instead in:",found)
out.close()
# the collection excerpts, exact instr as the app checks and the session claimed
coll=json.load(open(R8+"collection.fruscollection"))
bad=[]
for e in coll["entries"]:
    if e["kind"]=="excerpt":
        pos=db.execute("SELECT instr(body_text,?) FROM document_cache WHERE volume_id=? AND document_id=?",(e["text"],e["volumeId"],e["documentId"])).fetchone()[0]
        if pos<=0: bad.append((e["volumeId"],e["documentId"]))
print("\ncollection excerpts failing EXACT instr on body_text:",bad)
# excerpt<->overview correspondence: each overview document quotation should lie inside one of the 30 excerpts (normalized)
extexts=[(e["volumeId"],e["documentId"],N(e["text"])) for e in coll["entries"] if e["kind"]=="excerpt"]
for n,(st,q) in enumerate(spans,1):
    if n not in doc_spans or n==1: continue
    v,d=[c for c in cites if c[0]>st][0][1:]
    inside=all(any(ev==v and ed==d and s in et for ev,ed,et in extexts) for s in segs(q))
    if not inside: print(f"overview span [{n}] {v}/{d} is NOT inside a collection excerpt of that document")
