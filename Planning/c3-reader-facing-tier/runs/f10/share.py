import sqlite3,sys,re,json
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
label,match,vs,strict,tol=sys.argv[1:6]
n=int(sys.argv[6]) if len(sys.argv)>6 else 40
vols=open(R+"eap_vols.txt").read().split(",") if vs=="EAP" else (open(R+"all_vols.txt").read().split(",") if vs=="ALL" else vs.split(","))
ph=",".join("?"*len(vols))
hits=db.execute(f"select f.volume_id,f.document_id from frus_documents f join document_cache d on d.volume_id=f.volume_id and d.document_id=f.document_id where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0 and f.volume_id in ({ph}) order by f.volume_id,f.document_id",[match]+vols).fetchall()
N=len(hits)
k=N if N<300 and N<=n else n
if N<=n: samp=hits
else: samp=[hits[int(i*N/n)] for i in range(n)]
rs=re.compile(strict); rt=re.compile(tol,re.I)
ms=mt=0; miss=[]
for v,d in samp:
    h,dl,sn,b=db.execute("select header,dateline,source_note,body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    t=" ".join(((h or '')+" "+(dl or '')+" "+(sn or '')+" "+b).split())
    s=bool(rs.search(t)); tt=bool(rt.search(t)); ms+=s; mt+=tt
    if not tt: miss.append(v+"/"+d)
res=dict(label=label,match=match,scope=vs if vs in("EAP","ALL") else "list",N_hits=N,sample=len(samp),strict_regex=strict,tolerant_regex=tol,strict_share="%d of %d"%(ms,len(samp)),tolerant_share="%d of %d"%(mt,len(samp)),tolerant_misses=miss)
print(json.dumps(res,indent=1))
open(R+"shares.jsonl","a").write(json.dumps(res)+"\n")
open(R+"queries.log","a").write("python3 share.py %r %r %r %r %r %d  # evenly spaced sample from (volume_id,document_id)-sorted FTS hit list; python re on header+dateline+source_note+body_text whitespace-collapsed; strict case-sensitive, tolerant case-insensitive\n"%(label,match,vs,strict,tol,n))
