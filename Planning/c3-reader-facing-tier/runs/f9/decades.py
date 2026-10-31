# Q1 numerator: SELECT substr(dd.date_iso,1,3)||'0s', d.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
#   JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
#   WHERE frus_documents MATCH 'usia OR usi OR "information program" OR "psychological warfare" OR "Voice of America" OR "public diplomacy" OR "cultural exchange"'
#   AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (R) AND d.volume_id NOT IN ('frus1948v06','frus1949v07p1') GROUP BY 1,2
# Q2 R denominator: same join without MATCH. Q3 corpus denominator: SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_cache d JOIN document_dates dd ON ... WHERE non-apparatus AND dd.date_iso IS NOT NULL GROUP BY 1
import sqlite3,sys
sys.path.insert(0,'.'); from scopevols import R
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
Rx=[v for v in R if v not in ('frus1948v06','frus1949v07p1')]; ph=','.join('?'*len(Rx))
M='usia OR usi OR "information program" OR "psychological warfare" OR "Voice of America" OR "public diplomacy" OR "cultural exchange"'
J="FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id"
num={}
for dec,v,n in c.execute(f"SELECT substr(dd.date_iso,1,3)||'0s', d.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ({ph}) GROUP BY 1,2",[M]+Rx):
    num.setdefault(dec,{})[v]=n
rden=dict(c.execute(f"SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) {J} WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ({ph}) GROUP BY 1",Rx).fetchall())
cden=dict(c.execute(f"SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) {J} WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso IS NOT NULL GROUP BY 1").fetchall())
print("decade\tnum\tR_den\tper1000_R\tcorpus_den\tper1000_corpus\ttop_vol\ttop_share")
for dec in sorted(num):
    n=sum(num[dec].values()); tv=max(num[dec],key=num[dec].get)
    print(f"{dec}\t{n}\t{rden.get(dec)}\t{1000*n/rden[dec]:.1f}\t{cden.get(dec)}\t{1000*n/cden[dec]:.1f}\t{tv}\t{num[dec][tv]} of {n}")
