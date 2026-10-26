# Phrase counts over the chapter scope (scope.db tiers A+B, front matter and editorial notes excluded) with literal shares.
# FTS (porter stems) gives the hit list; regex (Python re, IGNORECASE; one regime for the whole family) gives the literal share.
import sqlite3, re, sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
db.execute("attach 'file:/Users/jbotts/frus-analysis/c3/runs/r12/scope.db?mode=ro' as s")
SEP=r"[\s\-,\(\)\.]*"
P={
 "international obligations": ('"international obligations"', r"international obligations", r"international"+SEP+r"obligations?"),
 "de facto": ('"de facto"', r"de facto", r"de"+SEP+r"facto"),
 "popular support": ('"popular support"', r"popular support", r"popular"+SEP+r"support(?:s|ed|ing)?"),
 "not recognize": ('"not recognize"', r"not recogni[sz]e", r"not"+SEP+r"recogni[sz](?:e|es|ed|ing)"),
}
REF={
 "international obligations": (r"recogn", "within 300 characters of a form of 'recogn'"),
 "de facto": (r"de"+SEP+r"facto"+SEP+r"(?:government|regime|authorit|administration|president|junta|power|control|status|recognition|recognized)", "followed within a separator run by government/regime/authority/administration/president/junta/power/control/status/recognition"),
 "not recognize": (r"(?:government|regime|junta|administration|president)", "within 300 characters of government/regime/junta/administration/president"),
 "popular support": (r"(?:government|regime|junta|administration|president)", "within 300 characters of government/regime/junta/administration/president"),
}
def norm(t): return re.sub(r"\s+"," ",t)
out=[]
for name,(fts,strict,tol) in P.items():
    q="""SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
         JOIN s.scope s ON s.volume_id=c.volume_id AND s.document_id=c.document_id
         WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 ORDER BY c.volume_id,c.document_id"""
    hits=db.execute(q,(fts,)).fetchall(); M=len(hits)
    if M<300: sample=hits; mode="census (whole set, M<300)"
    else:
        k=40; idx=[round(i*(M-1)/(k-1)) for i in range(k)]; sample=[hits[i] for i in idx]; mode="evenly spaced sample of 40"
    cs=ct=cr=0
    for v,d in sample:
        h,dl,sn,b=db.execute("select header,dateline,coalesce(source_note,''),body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
        t=norm(" ".join([h or "",dl or "",sn,b or ""]))
        if re.search(strict,t,re.I): cs+=1
        m=re.search(tol,t,re.I)
        if m: ct+=1
        # referent: any tolerant hit whose window / continuation satisfies the referent regex
        rr,desc=REF[name]; ok=False
        for m in re.finditer(tol,t,re.I):
            if name=="de facto":
                if re.match(rr,t[m.start():m.end()+60],re.I): ok=True;break
            else:
                w=t[max(0,m.start()-300):m.end()+300]
                if re.search(rr,w,re.I): ok=True;break
        cr+=ok
    n=len(sample)
    line="%s | FTS phrase %s | hits in scope (A+B) M=%d | %s n=%d | STRICT %d of %d | TOLERANT %d of %d | referent[%s] %d of %d"%(name,fts,M,mode,n,cs,n,ct,n,REF[name][1],cr,n)
    print(line); out.append(line)
open("phrase_shares.txt","w").write("\n".join(out)+"\n")
