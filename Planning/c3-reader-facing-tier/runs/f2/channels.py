import sqlite3,collections,re
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
wide=[(l.split("\t")[2],l.split("\t")[3]) for l in open("pd_ranked.tsv") if int(l.split("\t")[0])>=10]
print("wide set",len(wide))
cf=collections.Counter(); pa=collections.Counter(); n_pa_docs=0
for v,d in wide:
    r=c.execute("SELECT repository, record_group, series_name FROM document_sources WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if r:
        s=re.sub(r",?\s*Box.*$","",r[2] or "")
        cf[(r[0],r[1],s)]+=1
    else: cf[("(no row)","","")]+=1
    rows=c.execute("SELECT repository, collection, lot_file_norm, anchor FROM external_citations WHERE volume_id=? AND document_id=?",(v,d)).fetchall()
    if rows: n_pa_docs+=1
    for x in set(rows): pa[x]+=1
print("CAME-FROM"); [print(n,k) for k,n in cf.most_common(25)]
print("POINTED-AT docs with any row:",n_pa_docs); [print(n,k) for k,n in pa.most_common(25)]
