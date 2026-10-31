# false-friend test: family share vs control-phrase share, in the 14 cited volumes and in the whole index
import sqlite3
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
vols=sorted({l.split("/")[0] for l in open("cited.txt") if l.strip()})
ph=",".join("?"*len(vols))
BASE="FROM document_cache c WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
M="SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
print("DENOM SQL: SELECT COUNT(*)", BASE, "[AND c.volume_id IN (14 cited volumes)]"); print("MATCH SQL:", M, "[AND c.volume_id IN (...)]")
den_all=con.execute("SELECT COUNT(*) "+BASE).fetchone()[0]; den_s=con.execute("SELECT COUNT(*) "+BASE+" AND c.volume_id IN (%s)"%ph, vols).fetchone()[0]
for lab,m in [("family","corrupt OR bribe OR briberi OR graft OR kickback OR embezzl"),("control: \"united states\"",'"united states"'),("control: \"department of state\"",'"department of state"')]:
    a=con.execute(M,(m,)).fetchone()[0]; s=con.execute(M+" AND c.volume_id IN (%s)"%ph,(m,)+tuple(vols)).fetchone()[0]
    print("%-32s whole index %6d of %6d (%.4f)   cited volumes %5d of %5d (%.4f)  ratio %.2f" % (lab,a,den_all,a/den_all,s,den_s,s/den_s,(s/den_s)/(a/den_all)))
