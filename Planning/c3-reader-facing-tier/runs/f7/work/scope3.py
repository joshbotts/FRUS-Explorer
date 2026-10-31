import sqlite3,sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open("work/ea_vols_list.txt")]
q='"information agency" OR "information service" OR "information program" OR "psychological" OR propaganda OR "voice of america" OR usia OR usis OR "cultural exchange" OR "educational exchange"'
ph=",".join("?"*len(vols))
sql=f"""SELECT d.volume_id,COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE frus_documents MATCH ? AND d.volume_id IN ({ph}) AND d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY d.volume_id ORDER BY 2 DESC"""
cnt=dict(l.split() for l in open("work/ea_vol_counts.txt"))
tot=0
for v,n in db.execute(sql,[q]+vols):
    print(v,n,"of",cnt[v]); tot+=n
print("TOTAL",tot)
