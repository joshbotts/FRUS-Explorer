# Literal shares for the false-friend comparison counts (scope vs non-scope documents inside the same 41 volumes).
# Same regime as phrase_shares.py: FTS hit list sorted (volume_id, document_id); <300 -> census, else 40 evenly spaced; Python re IGNORECASE.
import sqlite3, re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
db.execute("attach 'file:/Users/jbotts/frus-analysis/c3/runs/r12/scope.db?mode=ro' as s")
SEP=r"[\s\-,\(\)\.]*"
Q=[("recogn* (prefix)","recogn*", r"\brecogni[sz](?:e|ed|es|ing)\b|\brecognition\b", r"recogn"),
   ("department of state",'"department of state"', r"department of state", r"department"+SEP+r"of"+SEP+r"state"),
   ("international obligations",'"international obligations"', r"international obligations", r"international"+SEP+r"obligations?")]
def norm(t): return re.sub(r"\s+"," ",t)
out=[]
for pop in ("scope","non-scope"):
  for name,fts,strict,tol in Q:
    cond = "s.volume_id IS NOT NULL" if pop=="scope" else "s.volume_id IS NULL"
    q="""SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
         LEFT JOIN s.scope s ON s.volume_id=c.volume_id AND s.document_id=c.document_id
         WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0
           AND c.volume_id IN (SELECT volume_id FROM s.scope) AND """+cond+""" ORDER BY c.volume_id,c.document_id"""
    hits=db.execute(q,(fts,)).fetchall(); M=len(hits)
    if M<300: sample=hits; mode="census"
    else:
        k=40; idx=[round(i*(M-1)/(k-1)) for i in range(k)]; sample=[hits[i] for i in idx]; mode="evenly spaced 40"
    cs=ct=0
    for v,d in sample:
        h,dl,sn,b=db.execute("select header,dateline,coalesce(source_note,''),body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
        t=norm(" ".join([h or "",dl or "",sn,b or ""]))
        cs+= bool(re.search(strict,t,re.I)); ct+= bool(re.search(tol,t,re.I))
    n=len(sample)
    line="%s | %s documents | FTS %s | M=%d | %s n=%d | STRICT %d of %d | TOLERANT %d of %d"%(name,pop,fts,M,mode,n,cs,n,ct,n)
    print(line); out.append(line)
open("phrase_shares2.txt","w").write("\n".join(out)+"\n")
