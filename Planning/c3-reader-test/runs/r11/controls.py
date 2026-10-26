# Controls in the same pass over the scope's volumes: positive "Department of State" (FTS phrase), negative ZZZ_IMPOSSIBLE_ZZZ; per volume, non-apparatus docs.
from db import q
vols=sorted({l.split()[0] for l in open("scope_final.tsv")})
pos=dict(q("SELECT f.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH '\"Department of State\"' AND c.is_front_matter=0 AND c.is_editorial_note=0 GROUP BY f.volume_id",tag="controls"))
neg=q("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ'",tag="controls")[0][0]
z=[v for v in vols if pos.get(v,0)==0]
print("scope volumes",len(vols),"positive control >0 in",len(vols)-len(z),"zero in",z,"negative control total",neg)
print("min positive", min((pos.get(v,0),v) for v in vols))
