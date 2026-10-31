import sqlite3,collections
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open('ea_vols.txt') if l.strip()]
vl=",".join("'%s'"%v for v in vols)
Q='"psychological warfare" OR "psychological strategy" OR "information program" OR USIA OR "Voice of America"'
hits=c.execute(f"""SELECT dc.volume_id, dc.document_id, substr(dd.date_iso,1,4) FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid
 LEFT JOIN document_dates dd ON dd.volume_id=dc.volume_id AND dd.document_id=dc.document_id
 WHERE frus_documents MATCH ? AND dc.volume_id IN ({vl}) AND dc.is_front_matter=0 AND dc.is_editorial_note=0 AND dc.volume_id NOT LIKE '%Ed2'""",(Q,)).fetchall()
print("TOPIC_SET",len(hits),"volumes",len({h[0] for h in hits}))
open('topic_set.tsv','w').write("\n".join(f"{v}\t{d}\t{y}" for v,d,y in sorted(hits)))
den=dict(c.execute(f"""SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_cache dc JOIN document_dates dd ON dd.volume_id=dc.volume_id AND dd.document_id=dc.document_id
 WHERE dc.volume_id IN ({vl}) AND dc.is_front_matter=0 AND dc.is_editorial_note=0 AND dd.date_iso IS NOT NULL GROUP BY 1""").fetchall())
by=collections.defaultdict(list); undated=0
for v,d,y in hits:
    if y: by[y[:3]+'0s'].append(v)
    else: undated+=1
for dec in sorted(den):
    L=by.get(dec,[]); n=len(L)
    top=collections.Counter(L).most_common(1)
    print(dec, n, den[dec], round(1000*n/den[dec],1) if den[dec] else '-', top[0] if top else '-', f"{top[0][1]} of {n}" if top else '')
print("undated",undated)
