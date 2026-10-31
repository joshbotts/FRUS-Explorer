import sqlite3,re
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
scope={l.split("\t")[0] for l in open("scope_volumes.tsv")}
S=r"[\s\-,().]+"
fam=[('"United States Information Agency" OR USIA', r"United States Information Agency|\bUSIA\b", r"United"+S+"States"+S+"Information"+S+r"Agenc(y|ies)|\bUSIA\b"),
 ('"psychological warfare" OR "psychological strategy" OR "psychological operations"', r"psychological (warfare|strategy|operations)", r"psychological"+S+r"(warfare|strateg(y|ies)|operations?)"),
 ('propaganda', r"\bpropaganda\b", r"\bpropagand\w*"),
 ('"image of the United States" OR "American image" OR "U.S. image"', r"image of the United States|American image|U\.S\. image", r"images?"+S+"of"+S+"the"+S+"United"+S+"States|American"+S+r"images?|U\.?S\.?"+S+r"images?"),
 ('"information program"', r"information program", r"information"+S+r"program(me)?s?"),
 ('"cultural exchange" OR "exchange of persons"', r"cultural exchange|exchange of persons", r"cultural"+S+r"exchanges?|exchanges?"+S+"of"+S+"persons?")]
log=open("queries.log","a")
sql="SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0"
for q,strict,tol in fam:
    log.write('sqlite3 -readonly DB "%s" [MATCH %r; restricted to scope_volumes.tsv; then SELECT header, dateline, source_note, body_text for 40 evenly spaced pairs; python re IGNORECASE strict=%r tolerant=%r]\n'%(sql,q,strict,tol))
    hits=sorted((v,d) for v,d in c.execute(sql,(q,)) if v in scope)
    M=len(hits); n=min(40,M); samp=[hits[int(i*M/n)] for i in range(n)]
    s=t=0; miss=[]
    for v,d in samp:
        h,dl,sn,b=c.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        txt=" ".join(" ".join(x or "" for x in (h,dl,sn,b)).split())
        a=bool(re.search(strict,txt,re.I)); bb=bool(re.search(tol,txt,re.I)); s+=a; t+=bb
        if not bb: miss.append(v+"/"+d)
    print("%s | hits in scope %d | sample %d | STRICT %d of %d | TOLERANT %d of %d | tolerant misses %s"%(q,M,n,s,n,t,n,miss))
