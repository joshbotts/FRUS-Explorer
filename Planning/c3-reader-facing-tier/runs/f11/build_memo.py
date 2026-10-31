import re,json,sqlite3
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
rd=lambda f:open(f).read().rstrip()
ov=open("overview.md").read()
c=json.load(open("collection.fruscollection"))
pairs=[(e["volumeId"],e["documentId"]) for e in c["entries"] if e["kind"]=="document"]
bodies={k:re.sub(r"\s+"," ",db.execute("select body_text from document_cache where volume_id=? and document_id=?",k).fetchone()[0]) for k in pairs}
qs=re.findall(r"“([^”]+)”",ov)
qrows=[]; 
for i,q in enumerate(qs,1):
    qq=re.sub(r"\s+"," ",q).strip(); hit=[k for k,b in bodies.items() if qq in b]
    k=hit[0]; qrows.append((i,k,qq))
qtab="\n".join("| Q%d | %s/%s | `SELECT body_text FROM document_cache WHERE volume_id='%s' AND document_id='%s'` | substring found after whitespace collapse: yes | “%s” |"%(i,k[0],k[1],k[0],k[1],qq) for i,k,qq in qrows)
# trace rows for quotes
def section_at(pos):
    heads=[(m.start(),m.group(0).strip("# *").split(" — ")[0]) for m in re.finditer(r"^(##+ .*|\*\*\d\. .*?\*\*)",ov,flags=re.M)]
    cur="top"
    for st,h in heads:
        if st<=pos: cur=h
    return cur
qt=[]
for m in re.finditer(r"“([^”]+)”",ov):
    i=len(qt)+1; qt.append("| Q%d | %s | %s | section 4 row Q%d |"%(i,section_at(m.start()),re.sub(r"\s+"," ",m.group(1))[:60].replace("|","/"),i))
M=open("memo_template.md").read()
M=M.replace("{{QTRACE}}","\n".join(qt))
M=M.replace("{{QUOTES}}",qtab)
for f in ["stats.out","share.out","arch.out","lots.out","absent.out","vec_setup.out","vec_nn.out","vec_ops2.out","excerpts.out","verify_collection.out","check_overview.out","final_numbers.out"]:
    M=M.replace("{{%s}}"%f,rd(f))
open("memo.md","w").write(M)
print("quotes",len(qrows),"memo chars",len(M))
