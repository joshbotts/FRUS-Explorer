# stats1.py: decade table (Cuba hits per 1,000 dated non-apparatus documents), top-volume share, controls, literal-share audit of the hit set
import sqlite3,re,collections
from h import *
c=con()
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
print("COVERAGE:",c.execute("SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache").fetchone())
print("CONTROLS (FTS, all columns): positive 'department AND state' =",c.execute("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'department AND state'").fetchone()[0],"; negative 'zzz_impossible_zzz' =",c.execute("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'zzz_impossible_zzz'").fetchone()[0])
print("positive control per volume: volumes with >=1 non-apparatus document matching 'department AND state':",c.execute("SELECT COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH 'department AND state' AND d.is_front_matter=0 AND d.is_editorial_note=0").fetchone()[0],"of 553")
den={}
for dec,n in c.execute("SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN %s GROUP BY 1"%ED2): den[dec]=n
hits=collections.defaultdict(collections.Counter)
rows=c.execute("SELECT substr(dd.date_iso,1,3)||'0s', d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH 'cuba OR cuban' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN %s"%ED2).fetchall()
allhits=sorted((r[1],r[2],r[0]) for r in rows)
for v,d,dec in allhits: hits[dec][v]+=1
print("decade | dated non-apparatus docs (M) | Cuba/Cuban FTS hits (N) | N of M per 1,000 | top volume (share of N)")
for dec in sorted(k for k in den if k):
    if dec<'1870s' or dec>'1980s': continue
    N=sum(hits[dec].values()); tv=hits[dec].most_common(1)
    print("%s | %d | %d | %.1f | %s %d of %d (%.2f)"%(dec,den[dec],N,1000*N/den[dec],tv[0][0] if tv else '-',tv[0][1] if tv else 0,N,(tv[0][1]/N if N else 0)))
scope=[h for h in allhits if h[2] and '1870s'<=h[2]<='1980s']
print("hit list 1870s-1980s:",len(scope))
step=len(scope)/40.0; samp=[scope[int(i*step)] for i in range(40)]
strict=re.compile(r"\bCub(?:a|an)\b",re.I); tol=re.compile(r"\bCub(?:a|an|ans|as)?\b",re.I)
s=t=0; miss=[]
for v,d,_ in samp:
    r=c.execute("SELECT header||' '||ifnull(dateline,'')||' '||ifnull(source_note,'')||' '||body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    r=re.sub(r"\s+"," ",r)
    a=bool(strict.search(r)); b=bool(tol.search(r)); s+=a; t+=b
    if not b: miss.append((v,d))
print("literal share, sample 40 of %d (every %.1fth): STRICT %d of 40; TOLERANT %d of 40; misses %s"%(len(scope),step,s,t,miss))
open("sample40_cuba.txt","w").write("\n".join("%s/%s"%(v,d) for v,d,_ in samp))
