# Phrase counts in the 938-doc scope (FTS phrase MATCH), and their literal share (census when hits<300, else 40 evenly spaced)
# over header+dateline+source_note+body_text concatenated, whitespace-collapsed; Python re with re.IGNORECASE throughout.
import re
from db import q
S=set(tuple(l.split()) for l in open("scope_all.tsv"))
SEP=r"[\s\-,().]+"
fam={
 "de facto government":(r"de facto government", r"de"+SEP+r"facto"+SEP+r"governments?"),
 "free elections":(r"free elections", r"free"+SEP+r"elections?"),
 "international obligations":(r"international obligations", r"international"+SEP+r"obligations?"),
 "constitutionally reorganized":(r"constitutionally reorganized", r"constitutionally"+SEP+r"reorganiz(e|ed|es|ing)"),
 "consult* AND recogni* (Resolution XXII era)":None,
}
for ph,pat in fam.items():
    if pat is None: continue
    hits=sorted((v,d) for v,d in q("SELECT volume_id, document_id FROM frus_documents WHERE frus_documents MATCH ?",('"%s"'%ph,),tag="shares") if (v,d) in S)
    sample=hits if len(hits)<300 else [hits[int(i*len(hits)/40)] for i in range(40)]
    st=tl=0; miss=[]
    for v,d in sample:
        h,dl,sn,b=q("SELECT header, coalesce(dateline,''), coalesce(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d),tag="shares")[0]
        t=re.sub(r"\s+"," "," ".join([h,dl,sn,b]))
        s1=bool(re.search(pat[0],t,re.I)); s2=bool(re.search(pat[1],t,re.I))
        st+=s1; tl+=s2
        if not s2: miss.append("%s/%s"%(v,d))
    print("%s | FTS hits in scope %d | %s %d | TOLERANT %d of %d | STRICT %d of %d | tolerant misses %s"%(ph,len(hits),"census" if len(hits)<300 else "sample",len(sample),tl,len(sample),st,len(sample),miss[:8]))
