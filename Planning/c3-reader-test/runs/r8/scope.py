import sqlite3,json,collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
la=[l.split("\t")[0] for l in open("la_volumes.tsv")]
la=[v for v in la if v not in ("frus1951-54IranEd2","frus1969-76ve15p2Ed2")]
Q='NEAR(recogn* government, 6) OR NEAR(recogn* regime, 6) OR NEAR(recogn* junta, 6)'
sql="""SELECT d.volume_id, d.document_id, dd.date_iso, d.header FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (%s)
ORDER BY d.volume_id, d.document_id""" % ",".join("'%s'"%v for v in la)
rows=db.execute(sql,(Q,)).fetchall()
with open("scope_hits.tsv","w") as f:
    for r in rows: f.write("\t".join("" if x is None else " ".join(str(x).split()) for x in r)+"\n")
print("scope hits:",len(rows),"in",len(set(r[0] for r in rows)),"volumes of",len(la),"LA volumes")
# per decade of doc date
dec=collections.Counter(); undated=0
for v,d,dt,h in rows:
    if dt: dec[dt[:3]+"0s"]+=1
    else: undated+=1
# baselines: dated non-apparatus docs per decade, whole corpus and LA volumes
base=dict(db.execute("""SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso IS NOT NULL AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') GROUP BY 1""").fetchall())
basela=dict(db.execute("""SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso IS NOT NULL AND d.volume_id IN (%s) GROUP BY 1""" % ",".join("'%s'"%v for v in la)).fetchall())
print("undated hits:",undated)
print("decade\thits\tLAdated\tper1000LA\tcorpus_dated\tper1000corpus")
out=[]
for k in sorted(set(dec)|set(base)):
    h=dec.get(k,0); b=basela.get(k,0); c=base.get(k,0)
    line=f"{k}\t{h}\t{b}\t{(1000*h/b if b else 0):.1f}\t{c}\t{(1000*h/c if c else 0):.1f}"
    print(line); out.append(line)
open("scope_decades.tsv","w").write("\n".join(out)+"\n")
pv=collections.Counter(r[0] for r in rows)
with open("scope_per_volume.tsv","w") as f:
    for v,c in pv.most_common(): f.write(f"{v}\t{c}\n")
print("top volumes:",pv.most_common(25))
