import sqlite3, re, sys, os
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con=sqlite3.connect(DB,uri=True)
FAM0=(r"\b(corrupt\w*|brib\w*|kickback\w*|embezzl\w*|malfeasance|peculat\w*|graft|venal\w*|nepotism|cronyism|payoffs?)\b")
FAM=re.compile(os.environ.get("PAT",FAM0),re.I)
W=int(sys.argv[1]); mx=int(sys.argv[2])
for arg in sys.argv[3:]:
    v,d=arg.split("/")
    r=con.execute("SELECT header,dateline,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    b=re.sub(r"\s+"," ",r[2])
    print("=====",v,d,"|",r[0][:100],"|",(r[1] or "")[:80],"| len",len(b))
    last=-1;k=0
    for m in FAM.finditer(b):
        if m.start()<last: continue
        s=max(0,m.start()-W); e=min(len(b),m.end()+W)
        print("  ..."+b[s:e]+"...")
        last=e;k+=1
        if k>=mx: break
