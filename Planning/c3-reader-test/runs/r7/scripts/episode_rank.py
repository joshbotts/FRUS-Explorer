# For each episode chapter, ranks the core-set documents in that chapter by bm25 for a recognition-policy query and prints the top rows.
import sqlite3, sys
R="/Users/jbotts/frus-analysis/c3/runs/r7/out/"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows=[l.rstrip("\n").split("\t") for l in open(R+"core_set_annotated.tsv")]
EP=[l.split("\t") for l in open(R+"episodes.tsv").read().strip().split("\n")]
Q='recogn* AND (policy OR principle OR conditions OR assurances OR elections OR obligations OR constitutional OR consultation)'
K=int(sys.argv[1]) if len(sys.argv)>1 else 4
for vid, sub in EP:
    docs={r[1]:r for r in rows if r[0]==vid and sub.lower() in r[7].lower()}
    if not docs: print(f"## {vid} [{sub}] -- no core docs"); continue
    ranked=con.execute("SELECT document_id, bm25(frus_documents) FROM frus_documents WHERE frus_documents MATCH ? AND volume_id=? ORDER BY bm25(frus_documents) LIMIT 400",(Q,vid)).fetchall()
    print(f"## {vid} [{sub}] core docs={len(docs)}")
    shown=0
    for d,s in ranked:
        if d in docs:
            r=docs[d]; print(f"  {vid}/{d}\t{r[2]}\t{r[4]}ch\t{r[5][:95]}\t{r[6][:40]}"); shown+=1
            if shown>=K: break
    if shown==0:
        for d,r in list(docs.items())[:K]: print(f"  (unranked) {vid}/{d}\t{r[2]}\t{r[4]}ch\t{r[5][:95]}")
