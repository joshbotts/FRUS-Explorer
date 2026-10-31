import sqlite3,sys,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
def run(match,vols=None,limit=40,snip=True):
    q="""select f.volume_id,f.document_id,substr(d.header,1,100),bm25(frus_documents) s
    from frus_documents f join document_cache d on d.volume_id=f.volume_id and d.document_id=f.document_id
    where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0"""
    args=[match]
    if vols:
        q+=" and f.volume_id in (%s)"%",".join("?"*len(vols)); args+=vols
    q+=" order by s limit ?"; args.append(limit)
    return db.execute(q,args).fetchall()
if __name__=="__main__":
    match=sys.argv[1]; vols=sys.argv[2].split(",") if len(sys.argv)>2 and sys.argv[2] else None
    lim=int(sys.argv[3]) if len(sys.argv)>3 else 40
    open("/Users/jbotts/frus-analysis/c3f/runs/f10/queries.log","a").write("python3 fts.py %r %r %d  # FTS5 MATCH join document_cache on (volume_id,document_id), front/editorial excluded, order by bm25 asc\n"%(match,sys.argv[2] if len(sys.argv)>2 else '',lim))
    for r in run(match,vols,lim): print(r[0],r[1],r[2],round(r[3],1))
