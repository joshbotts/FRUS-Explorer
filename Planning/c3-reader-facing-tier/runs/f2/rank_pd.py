import sqlite3,re
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=['frus1917-72PubDip','frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30']
pat=re.compile(r"\b(Japan\w*|Korea\w*|China|Chinese|Taiwan|Vietnam\w*|Viet-Nam\w*|Philippin\w*|Indonesia\w*|Thai\w*|Laos|Lao|Cambodia\w*|Burm\w*|Malaysia\w*|Singapore|East Asia\w*|Far East\w*|Asian?s?|Pacific|Australia\w*|New Zealand|Okinawa\w*|Peking|Hanoi|Saigon|Tokyo)\b")
rows=c.execute("SELECT volume_id, document_id, header, length(body_text), body_text FROM document_cache WHERE volume_id IN (%s) AND is_front_matter=0 AND is_editorial_note=0"%",".join("?"*len(vols)),vols).fetchall()
res=[]
for v,d,h,L,b in rows:
    n=len(pat.findall(b)); res.append((n, n*1000/max(L,1), v,d," ".join(h.split())[:130],L))
res.sort(reverse=True)
with open("pd_ranked.tsv","w") as f:
    for r in res: f.write("\t".join(map(str,r))+"\n")
print(len(rows))
for r in res[:70]: print(r[0],round(r[1],1),r[2],r[3],r[5],r[4])
