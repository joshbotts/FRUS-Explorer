import sqlite3,sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
match=sys.argv[1]; vs=sys.argv[2]; lim=int(sys.argv[3])
vols=open("/Users/jbotts/frus-analysis/c3f/runs/f10/eap_vols.txt").read().split(",") if vs=="EAP" else (vs.split(",") if vs else None)
open("/Users/jbotts/frus-analysis/c3f/runs/f10/queries.log","a").write("python3 snip.py %r %r %d  # FTS5 MATCH + snippet(), join document_cache on (volume_id,document_id), apparatus excluded, order by bm25 asc\n"%(match,vs if vs!="EAP" else "EAP(99 vols)",lim))
q="""select f.volume_id,f.document_id,substr(d.header,1,90),snippet(frus_documents,-1,'[',']',' … ',28) from frus_documents f join document_cache d on d.volume_id=f.volume_id and d.document_id=f.document_id where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0"""
a=[match]
if vols: q+=" and f.volume_id in (%s)"%",".join("?"*len(vols)); a+=vols
q+=" order by bm25(frus_documents) limit ?"; a.append(lim)
for r in db.execute(q,a): print(r[0]+"/"+r[1],"|",r[2],"\n    ",(r[3] or '').replace("\n"," "))
