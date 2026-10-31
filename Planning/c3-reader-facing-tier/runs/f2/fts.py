import sys, sqlite3, collections
LOG="/Users/jbotts/frus-analysis/c3f/runs/f2/queries.log"
scope={l.split("\t")[0]:l.split("\t")[1] for l in open("/Users/jbotts/frus-analysis/c3f/runs/f2/scope_volumes.tsv")}
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for term in sys.argv[1:]:
    sql=("SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid "
         "WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0")
    open(LOG,"a").write("sqlite3 -readonly DB \"%s\" [MATCH %r; then filtered in python to scope_volumes.tsv]\n"%(sql,term))
    rows=c.execute(sql,(term,)).fetchall()
    tot=len(rows); vols=collections.Counter(); cls=collections.Counter()
    for v,dd in rows:
        if v in scope: cls[scope[v]]+=1; vols[v]+=1
    print(term,"| corpus",tot,"| EA",cls["EA"],"| PD",cls["PD"],"| top",vols.most_common(8))
