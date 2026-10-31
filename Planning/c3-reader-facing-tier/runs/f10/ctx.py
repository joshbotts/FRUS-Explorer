import sqlite3,sys,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
match,rx,vs,lim=sys.argv[1],sys.argv[2],sys.argv[3],int(sys.argv[4])
w=int(sys.argv[5]) if len(sys.argv)>5 else 220
vols=open(R+"eap_vols.txt").read().split(",") if vs=="EAP" else (vs.split(",") if vs else None)
open(R+"queries.log","a").write("python3 ctx.py %r %r %r %d  # FTS candidates (apparatus excluded, bm25 asc) then python re.I regex on header+dateline+source_note+body_text whitespace-collapsed\n"%(match,rx,vs if vs!="EAP" else "EAP(99)",lim))
q="""select f.volume_id,f.document_id,d.header,d.dateline,d.source_note,d.body_text from frus_documents f join document_cache d on d.volume_id=f.volume_id and d.document_id=f.document_id where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0"""
a=[match]
if vols: q+=" and f.volume_id in (%s)"%",".join("?"*len(vols)); a+=vols
q+=" order by bm25(frus_documents) limit ?"; a.append(lim*4)
pat=re.compile(rx,re.I); n=0
for v,d,h,dl,sn,b in db.execute(q,a):
    t=" ".join(((h or '')+" "+(dl or '')+" "+(sn or '')+" "+b).split())
    ms=list(pat.finditer(t))
    if not ms: continue
    n+=1
    print("##",v+"/"+d,"|",(h or '')[:80].replace("\n"," "),"|",(dl or '')[:50], "| hits",len(ms))
    for m in ms[:2]:
        print("   …"+t[max(0,m.start()-w):m.end()+w]+"…")
    if n>=lim: break
