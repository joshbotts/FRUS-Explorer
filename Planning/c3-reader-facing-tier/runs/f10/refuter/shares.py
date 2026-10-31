import sqlite3,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
eap=open(R+"eap_vols.txt").read().strip().split(","); scope=open(R+"scope105.txt").read().strip().split(",")
def share(match,vols,strict,tol,n=40):
    ph=",".join("?"*len(vols))
    hits=db.execute(f"select f.volume_id,f.document_id from frus_documents f join document_cache d on d.volume_id=f.volume_id and d.document_id=f.document_id where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0 and f.volume_id in ({ph}) order by f.volume_id,f.document_id",[match]+vols).fetchall()
    N=len(hits); samp=hits if N<=n else [hits[int(i*N/n)] for i in range(n)]
    rs=re.compile(strict); rt=re.compile(tol,re.I); ms=mt=0; miss=[]
    for v,d in samp:
        h,dl,sn,b=db.execute("select header,dateline,source_note,body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
        t=" ".join(((h or '')+" "+(dl or '')+" "+(sn or '')+" "+b).split())
        ms+=bool(rs.search(t)); tt=bool(rt.search(t)); mt+=tt
        if not tt: miss.append(v+"/"+d)
    return N,len(samp),ms,mt,miss
FA='"United States Information Agency" OR "United States Information Service" OR USIA OR USIS'
S=r"United States Information (Agency|Service)|USIA|USIS"; T=r"(U\.?\s?S\.?|United\s+States)[\s-]+Information[\s,.-]+(Agenc|Servic)\w*|USIA|USIS|U\.S\.I\.[AS]\."
print("FAMILY_A_EAP:",share(FA,eap,S,T),"(memo 898; 32 of 40; 32 of 40)")
print("famA_scope105:",share(FA,scope,S,T),"(memo 1,538; 34 of 40; 34 of 40)")
print("boxer_indemnity_EAP:",share('"Boxer indemnity"',eap,r"Boxer [Ii]ndemnity",r"Boxer[\s,.\-]+indemnit\w*"),"(memo 99; 38 of 40; 40 of 40)")
print("propaganda_scope105:",share('propaganda',scope,r"propaganda",r"propaganda\w*"),"(memo 3,407; 40/40)")
print("prestige_scope105:",share('prestige',scope,r"prestige",r"prestig\w*"),"(memo 2,108; 40/40)")
# what do the tolerant misses contain? (the USI collision claim)
for v,d in [("frus1948v06","d111"),("frus1947v06","d831")]:
    h,dl,sn,b=db.execute("select header,dateline,source_note,body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    t=" ".join(((h or '')+" "+(dl or '')+" "+(sn or '')+" "+b).split())
    print(" miss",v+"/"+d,"USI-words:",sorted(set(re.findall(r'\bUSI\w*',t)))[:6])
