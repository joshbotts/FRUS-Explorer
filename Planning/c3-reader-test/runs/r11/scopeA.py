# Part A scope: chap_docs.tsv minus false chapters, keep non-apparatus docs whose text matches recogni*
import csv,re,json
from db import q
BAD=re.compile(r'Proposed changes in the regime of the Mixed Courts|divest his government|The war prior to the entrance')
rows=[l.rstrip("\n").split("\t") for l in open("chap_docs.tsv")]
keep=[(v,d,c) for v,d,c in rows if not BAD.search(c)]
print("chapter docs",len(rows),"after false-chapter removal",len(keep))
hits=set((a,b) for a,b in q("SELECT volume_id, document_id FROM frus_documents WHERE frus_documents MATCH 'recogni*'",tag="scopeA"))
meta={(a,b):(fm,en) for a,b,fm,en in q("SELECT volume_id, document_id, is_front_matter, is_editorial_note FROM document_cache",tag="scopeA")}
missing=[(v,d) for v,d,c in keep if (v,d) not in meta]
print("not in document_cache",len(missing),missing[:5])
app=[(v,d) for v,d,c in keep if (v,d) in meta and (meta[(v,d)][0] or meta[(v,d)][1])]
print("apparatus (front matter/editorial note) dropped",len(app))
nona=[(v,d,c) for v,d,c in keep if (v,d) in meta and not (meta[(v,d)][0] or meta[(v,d)][1])]
A=[(v,d,c) for v,d,c in nona if (v,d) in hits]
print("non-apparatus",len(nona),"of which match recogni*",len(A),"volumes",len({v for v,_,_ in A}))
with open("scopeA.tsv","w") as f:
    for r in A: f.write("\t".join(r)+"\n")
