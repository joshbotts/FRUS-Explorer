from h import *
import re
c=conn()
Q='''(USIS OR USIA OR JUSPAO OR "Information Agency" OR "Information Service" OR "psychological warfare" OR "psychological operations" OR "psychological strategy" OR "information program" OR "cultural exchange" OR "educational exchange" OR Fulbright OR "Voice of America" OR "exchange of persons" OR "hearts and minds" OR "cultural program" OR "Asia Foundation" OR "leader grant" OR "information officer" OR "cultural affairs" OR "cultural relations" OR "public diplomacy" OR "information activities")'''
SQL="SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ? ORDER BY d.volume_id, d.document_id"
pairs=c.execute(SQL,(Q,)).fetchall()
N=len(pairs); print('hit list',N)
k=40
idx=[int(i*N/k) for i in range(k)]
sample=[pairs[i] for i in idx]
phr=["Information Agency","Information Service","psychological warfare","psychological operations","psychological strategy","information program","cultural exchange","educational exchange","Voice of America","exchange of persons","hearts and minds","cultural program","Asia Foundation","leader grant","information officer","cultural affairs","cultural relations","public diplomacy","information activities"]
acr=["USIS","USIA","JUSPAO","Fulbright"]
strict=re.compile('|'.join([r'\b'+re.escape(p)+r'\b' for p in phr]+[r'\b'+a+r'\b' for a in acr]),re.I)
def tol(p):
    ws=p.split(); out=[]
    for w in ws:
        wl=w.lower()
        if wl=='activities': out.append(r'activit(?:y|ies)')
        elif wl in ('of','and','america','asia','voice','hearts','minds','agency','service','foundation'): out.append(re.escape(w))
        else: out.append(re.escape(w)+r'(?:s|es|ed|ing)?')
    return r'\b'+r'[\s\-,().]+'.join(out)+r'\b'
tolr=re.compile('|'.join([tol(p) for p in phr]+[r'\b'+a+r'\b' for a in acr]),re.I)
sq="SELECT header||' '||coalesce(dateline,'')||' '||coalesce(source_note,'')||' '||body_text FROM document_cache WHERE volume_id=? AND document_id=?"
ns=nt=0; miss=[]
for v,i in sample:
    t=re.sub(r'\s+',' ',c.execute(sq,(v,i)).fetchone()[0])
    s=bool(strict.search(t)); tt=bool(tolr.search(t))
    ns+=s; nt+=tt
    if not tt: miss.append((v,i))
print('STRICT',ns,'of',k,'TOLERANT',nt,'of',k)
print('sample',sample)
print('tolerant misses',miss)
