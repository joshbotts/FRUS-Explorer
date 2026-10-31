import re,sqlite3,json
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"; RUN="/Users/jbotts/frus-analysis/c3f/runs/f2/"
c=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
ov=open(RUN+"overview.md").read()
body,cited=ov.split("## Documents cited")
# resolve the Documents cited list
res={}
for line in cited.splitlines():
    m=re.search(r"Foreign Relations of the United States, (\d{4})–(\d{4}), .*?Volume ([IVXL]+)(?:, Part (\d+))?.*?Document (\d+) — https://history\.state\.gov/historicaldocuments/([^/\s]+)/(d\d+)",line)
    if m:
        key=(m.group(1)+"–"+m.group(2),m.group(3),m.group(4)); pair=(m.group(6),m.group(7))
        assert m.group(5)==m.group(7)[1:], line
        res.setdefault(key,set()).add(pair[0])
print("Documents-cited list: %d entries; volume keys:"%len(re.findall(r"^\d+\. ",cited,re.M)))
for k,v in sorted(res.items()): print("  ",k,"->",sorted(v))
assert all(len(v)==1 for v in res.values()), "ambiguous volume key"
def resolve(cit):
    m=re.match(r"\((\d{4}–\d{4}), Volume ([IVXL]+)(?:, Part (\d+))?, Document (\d+)\)",cit)
    key=(m.group(1),m.group(2),m.group(3)); return (next(iter(res[key])),"d"+m.group(4))
CIT=re.compile(r"\((\d{4}–\d{4}), Volume ([IVXL]+)(?:, Part (\d+))?, Document (\d+)\)")
def norm(s): return re.sub(r"[^a-z0-9]","",s.lower())
def check(q,pair):
    r=c.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?",pair).fetchone()
    if not r: return "NO SUCH ROW",[]
    full=norm("".join(x or "" for x in r)); bodyn=norm(r[3] or "")
    segs=[s for s in re.split(r"\[\.\.\.\]|\.\.\.|…",q) if norm(s)]
    pos=0; offs=[]
    for s in segs:
        i=full.find(norm(s),pos)
        if i<0: return "FAIL segment %r"%s[:50],offs
        offs.append(i); pos=i+len(norm(s))
    inbody=all(bodyn.find(norm(s))>=0 for s in segs)
    return "OK"+("" if inbody else " (not all in body_text alone)"),offs
# paragraphs with offsets
paras=[]; pos=0
for p in body.split("\n\n"):
    paras.append((pos,p)); pos+=len(p)+2
QUOTE=re.compile(r"\"([^\"]+)\"|“([^”]+)”")
results=[]; n=0
for pstart,p in paras:
    cits=[(m.start(),m.group(0)) for m in CIT.finditer(p)]
    for m in QUOTE.finditer(p):
        q=m.group(1) or m.group(2); n+=1
        nxt=[cc for s,cc in cits if s>=m.end()]
        prv=[cc for s,cc in cits if s<m.start()]
        how="next-in-paragraph" if nxt else ("PREVIOUS-PARAGRAPH-FALLBACK" if not prv else "previous-in-paragraph")
        cit=nxt[0] if nxt else (prv[-1] if prv else None)
        if cit is None:
            # fall back to the nearest preceding citation anywhere before this paragraph
            allprev=[(pstart2+mm.start(),mm.group(0)) for pstart2,p2 in paras if pstart2<pstart for mm in CIT.finditer(p2)]
            cit=allprev[-1][1] if allprev else None
        pair=resolve(cit) if cit else None
        results.append((n,q,cit,pair,how,p[:60].replace("\n"," ")))
print("\n== overview quoted strings (%d) =="%n)
blk=[l for l in body.splitlines() if l.startswith(">")]
print("block quotes:",len(blk))
tot=ver=0; nondoc=[]
for n,q,cit,pair,how,ctx in results:
    # decide whether this is a document quotation: it has a citation in the same paragraph
    if how=="PREVIOUS-PARAGRAPH-FALLBACK" or cit is None:
        v,o="(no citation in paragraph; fallback %s -> %s)"%(cit,pair),[]
    if cit is None:
        nondoc.append((n,q)); print("Q%02d NOT-A-DOCUMENT-QUOTATION (no citation) %r  [para: %s]"%(n,q,ctx)); continue
    verdict,offs=check(q,pair); tot+=1; ver+=verdict.startswith("OK")
    print("Q%02d %-4s %s/%s %s | %r%s"%(n,verdict[:4],pair[0],pair[1],cit,q[:70],"" if how=="next-in-paragraph" else "  <<"+how+">>"), "" if verdict.startswith("OK") else verdict)
print("document-attributed quoted strings checked:",tot,"verified:",ver)
print("\n== collection excerpts ==")
coll=json.load(open(RUN+"collection.fruscollection"))
docs={(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"}
et=ev=0
for e in coll["entries"]:
    if e["kind"]=="excerpt":
        et+=1; verdict,offs=check(e["text"],(e["volumeId"],e["documentId"])); ev+=verdict.startswith("OK")
        print("EX %-4s %s/%s offs %s | %r%s"%(verdict[:4],e["volumeId"],e["documentId"],offs,e["text"][:70],"" if verdict.startswith("OK") else " "+verdict), "| parent doc in collection:",(e["volumeId"],e["documentId"]) in docs)
print("excerpts:",et,"verified:",ev)
print("\n== single-quoted phrases inside collection notes (extra) ==")
for e in coll["entries"]:
    for note in e.get("notes",[]):
        for m in re.finditer(r"'([^']+)'",note):
            verdict,offs=check(m.group(1),(e["volumeId"],e["documentId"])); print("NOTE",verdict[:4],e["volumeId"],e["documentId"],repr(m.group(1)),offs)
