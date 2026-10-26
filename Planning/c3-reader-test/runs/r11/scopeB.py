# Part B: NEAR recognition query (nearq.txt) over non-apparatus documents that are Latin American by TEI chain (latam_docs.tsv)
# or sit in a whole-volume Latin American volume (modvols.txt), minus Part A; second editions suppressed.
from db import q
NEARQ=open("nearq.txt").read().strip()
mod=[x.strip().strip("'") for x in open("modvols.txt").read().split(",")]
lat=set(tuple(l.split("\t")[:2]) for l in open("latam_docs.tsv"))
A=set(tuple(l.split("\t")[:2]) for l in open("scopeA.tsv"))
hits=q("SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0",(NEARQ,),tag="scopeB")
print("NEAR hits, non-apparatus, whole corpus:",len(hits))
B=[(v,d) for v,d in hits if ((v,d) in lat or v in mod) and (v,d) not in A and not v.endswith("Ed2")]
print("Latin American, not in A:",len(B),"volumes",len({v for v,_ in B}))
AinNear=len([1 for v,d in hits if (v,d) in A])
print("Part A docs also matching NEAR:",AinNear,"of",len(A))
import collections
c=collections.Counter(v for v,_ in B)
print(sorted(c.items()))
open("scopeB.tsv","w").write("".join("%s\t%s\n"%x for x in sorted(B)))
