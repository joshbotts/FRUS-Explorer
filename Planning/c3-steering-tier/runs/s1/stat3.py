import sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
from final_set import FINAL
fv=sorted({v for v,d in FINAL if v>="frus1950"})  # post-1950 finding volumes
fvs=",".join("'%s'"%v for v in fv)
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
BASE="c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN "+ED2+" AND t.date_iso>='1950' AND t.date_iso<'1981'"
def share(match,inset):
    cond="c.volume_id IN (%s)"%fvs if inset else "c.volume_id NOT IN (%s)"%fvs
    tot=con.execute("SELECT COUNT(*) FROM document_cache c JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE "+BASE+" AND "+cond).fetchone()[0]
    q="SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE frus_documents MATCH ? AND "+BASE+" AND "+cond
    h=con.execute(q,(match,)).fetchone()[0]
    return h,tot
print("post-1950 finding volumes (",len(fv),"):",fv)
for name,m in [("corrupt (question's term)","corrupt"),("CONTROL phrase 'economic assistance'",'"economic assistance"'),("POSITIVE control 'department of state'",'"department of state"'),("NEGATIVE control ZZZ_IMPOSSIBLE_ZZZ","zzz_impossible_zzz")]:
    a=share(m,True); b=share(m,False)
    print(f"{name}: finding volumes {a[0]} of {a[1]} ({1000*a[0]/a[1]:.1f}/1000) | other volumes 1950-1980 {b[0]} of {b[1]} ({1000*b[0]/b[1]:.1f}/1000)")
