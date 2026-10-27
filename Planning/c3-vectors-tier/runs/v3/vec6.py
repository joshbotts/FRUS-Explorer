from vec import *
import sqlite3, itertools
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
L=[tuple(l.split()) for l in open("docs_list.tsv") if l.strip()]
S=signs()
bad=[]
for v,d in L:
    r=db.execute("select is_front_matter,is_editorial_note,length(body_text) from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    if r is None or r[0] or r[1]: bad.append((v,d,r))
print("collection candidates:",len(L),"not-in-db-or-apparatus:",bad, "Ed2 volumes:",[x for x in L if x[0].endswith("Ed2")])
print("in vector index:",sum((v,d) in row_of for v,d in L),"of",len(L))
# near-duplicate scan within list
pairs=[]
for (a,b) in itertools.combinations(L,2):
    if a in row_of and b in row_of: pairs.append((bin(S[row_of[a]]^S[row_of[b]]).count("1"),a,b))
pairs.sort(); print("closest pairs within list:",pairs[:6])
# explicit reprint check: 1881/d405 vs 1894app2/d394
print("1881/d405 vs 1894app2/d394 Hamming:",bin(S[row_of[("frus1881","d405")]]^S[row_of[("frus1894app2","d394")]]).count("1"))
nn=knn(row_of[("frus1881","d405")],5); print("neighbours of frus1881/d405:",[(d,doc_of[r]) for d,r in nn])
