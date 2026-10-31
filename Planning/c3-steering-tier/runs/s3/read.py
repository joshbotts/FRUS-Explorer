import sqlite3, sys, re, os
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
LIT=re.compile(r"questionable payments?|improper payments?|illicit payments?|commissions?|corrupt\w*|brib\w*|graft\w*|kickback\w*|embezzl\w*|pay-?offs?\b|Lockheed", re.I)
SQL="SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?"
for pair in sys.argv[1:]:
    v,d=pair.split("/")
    r=con.execute(SQL,(v,d)).fetchone()
    if not r: print("MISSING",pair); continue
    h,dl,sn,b,L=r
    open("raw/%s__%s.txt"%(v,d),"w").write("\n".join([h or "",dl or "",sn or "",b or ""]))
    print("=====",pair,"len",L,"|",(h or "")[:100])
    txt=re.sub(r"\s+"," ",b)
    last=-1
    for m in LIT.finditer(txt):
        if m.start()<last: continue
        s=max(0,m.start()-250); last=m.end()+250; print("  ..."+txt[s:last]+"...")
