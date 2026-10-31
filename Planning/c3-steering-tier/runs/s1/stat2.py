import sqlite3, collections
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
BASE="c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN "+ED2
Q1="SELECT substr(t.date_iso,1,3)||'0s', COUNT(*) FROM document_cache c JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE "+BASE+" AND t.date_iso IS NOT NULL GROUP BY 1"
Q2="SELECT substr(t.date_iso,1,3)||'0s', c.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE frus_documents MATCH 'corrupt' AND "+BASE+" AND t.date_iso IS NOT NULL GROUP BY 1,2"
print("Q1:",Q1); print("Q2:",Q2)
base=dict(con.execute(Q1).fetchall()); hit=collections.defaultdict(dict)
for d,v,n in con.execute(Q2): hit[d][v]=n
print("decade | dated non-apparatus docs | docs with stem 'corrupt' | per 1,000 | top volume (share of numerator)")
for d in sorted(base):
    h=sum(hit[d].values()) if d in hit else 0
    if base[d]<400 and h==0: continue
    top=max(hit[d].items(),key=lambda x:x[1]) if h else ("-",0)
    print(f"{d} | {base[d]} | {h} | {1000*h/base[d]:.1f} | {top[0]} {top[1]} of {h}")
