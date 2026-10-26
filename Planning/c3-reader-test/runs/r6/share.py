# Literal share of FTS phrase hits. Hit list: SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid
#   WHERE frus_documents MATCH ? AND dc.is_front_matter=0 AND dc.is_editorial_note=0 ORDER BY dc.volume_id, dc.document_id
# Text tested: header+' '+dateline+' '+source_note+' '+body_text, whitespace-collapsed. Python re with re.IGNORECASE.
# Census when hits <300, else 40 evenly spaced. STRICT = single spaces; TOLERANT = inflections + [\s\-,().]+ between words.
import sqlite3, re
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
SEP=r"[\s\-,().]+"
FAM=[
('"orderly processes of just government"', r"orderly processes of just government", SEP.join([r"orderly",r"process(?:es)?",r"of",r"just",r"governments?"])),
('"coup d etat or a revolution"', r"coup d[’']état or a revolution", SEP.join([r"coups?",r"d[’']?\s?[ée]tat",r"or",r"an?",r"revolutions?"])),
('"Resolution XXXV"', r"Resolution XXXV\b", SEP.join([r"Resolutions?",r"XXXV\b"])),
('"Resolution XXII"', r"Resolution XXII\b", SEP.join([r"Resolutions?",r"XXII\b"])),
('"continuity of diplomatic relations"', r"continuity of diplomatic relations", SEP.join([r"continuit(?:y|ies)",r"of",r"diplomatic",r"relations?"])),
('"recognition does not imply"', r"recognition does not imply", SEP.join([r"recognitions?",r"(?:does|do|did)",r"not",r"impl(?:y|ies|ied)"])),
('"de facto in control"', r"de facto in control", SEP.join([r"de",r"facto",r"in",r"control"])),
('"no active resistance"', r"no active resistance", SEP.join([r"no",r"active",r"resistances?"])),
('"intention to fulfill"', r"intention to fulfill", SEP.join([r"intentions?",r"to",r"fulfill?(?:s|ed|ing)?"])),
]
import sys
for q,strict,tol in FAM:
    hits=con.execute("SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH ? AND dc.is_front_matter=0 AND dc.is_editorial_note=0 ORDER BY dc.volume_id, dc.document_id",(q,)).fetchall()
    N=len(hits)
    samp=hits if N<300 else [hits[int(i*N/40)] for i in range(40)]
    s=t=0; miss=[]
    for v,d in samp:
        h,dl,sn,b=con.execute("SELECT header, coalesce(dateline,''), coalesce(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        x=re.sub(r"\s+"," ",h+" "+dl+" "+sn+" "+b)
        a=bool(re.search(strict,x,re.I)); c=bool(re.search(tol,x,re.I)); s+=a; t+=c
        if not c: miss.append(v+"/"+d)
    print("%s\thits=%d\ttested=%d (%s)\tSTRICT=%d of %d\tTOLERANT=%d of %d\tmisses=%s"%(q,N,len(samp),"census" if N<300 else "sample40",s,len(samp),t,len(samp),",".join(miss[:8])),flush=True)
