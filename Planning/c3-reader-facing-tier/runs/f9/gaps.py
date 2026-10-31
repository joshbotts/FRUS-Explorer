# gap searches over R+I (non-apparatus), same pass with positive/negative controls
import sqlite3,sys,re
sys.path.insert(0,'.'); from scopevols import R,I
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=R+I; ph=','.join('?'*len(vols))
SQL=f"SELECT COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ({ph})"
Q={'POS':'"Department of State"','NEG':'ZZZ_IMPOSSIBLE_ZZZ','soft power':'"soft power"','soft (relaxed)':'soft',
 'poll/survey + USIA/USIS':'(poll OR survey) AND (usia OR usi)','poll/survey + USIA/USIS + Japan':'(poll OR survey) AND (usia OR usi) AND (japan OR japanes)',
 'USIA/USIS + Australia/NZ':'(usia OR usi) AND (australia OR "new zealand")','USIA/USIS + Pacific islands':'(usia OR usi) AND (micronesia OR fiji OR "trust territory" OR samoa OR guam)',
 'Fulbright':'fulbright','Fulbright + evaluat/effect':'fulbright AND (evaluat OR effect OR impact)',
 'Asian/Oriental mind(ality)':'"Asian mind" OR "Oriental mind" OR "Asian mentality" OR "Oriental mentality" OR "Asian psychology" OR "Oriental psychology"',
 'face (loss of face)':'"lose face" OR "loss of face" OR "save face" OR "saving face" OR "face saving"'}
for k,q in Q.items():
    n,nv=c.execute(SQL,[q]+vols).fetchone(); print(f"{k}\t{q}\t{n} docs\t{nv} vols")
rows=c.execute(f"SELECT d.volume_id,d.document_id,d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ({ph}) ORDER BY 1,2",[Q['Asian/Oriental mind(ality)']]+vols).fetchall()
st=tl=0
for v,d,b in rows:
    b=re.sub(r'\s+',' ',b)
    s=re.search(r'(Asian|Oriental) (mind|mentality|psychology)',b,re.I); t=re.search(r'(Asian|Oriental)\w*[\s\-,().]+(mind|mentalit|psycholog)\w*',b,re.I)
    st+=bool(s); tl+=bool(t)
    m=re.search(r'.{120}(Asian|Oriental)\w*[\s\-,().]+(mind|mentalit|psycholog)\w*.{120}',b,re.I)
    print(' ',v,d,'|',m.group(0) if m else None)
print(f"Asian/Oriental mind census: STRICT {st} of {len(rows)}, TOLERANT {tl} of {len(rows)} (Python re IGNORECASE)")
