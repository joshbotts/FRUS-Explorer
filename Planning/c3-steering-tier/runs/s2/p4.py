# absences and their relaxed forms
import sqlite3
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
M="SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND c.volume_id LIKE ?"
print("SQL:", M)
for m, vl in [('"foreign corrupt practices"','frus1981-88%'), ('"corrupt practices"','frus1981-88%'), ('corrupt OR bribe OR briberi','frus1981-88%'), ('*','frus1981-88%'),
              ('lockheed AND (bernhard OR netherlands OR dutch)','%'), ('lockheed AND (italy OR italian)','%'), ('lockheed','%'),
              ('"church committee" AND (bribe OR bribery OR payments)','%'), ('"church committee"','%'),
              ('"anti corruption" OR anticorruption','%'),
              ('(bribe OR bribery) AND (consul OR consular) AND (fee OR fees)','%'), ('bribe OR bribery','%'),
              ('ZZZ_IMPOSSIBLE_ZZZ','%'), ('"department of state"','%')]:
    if m=='*':
        r=con.execute("SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id LIKE ?", (vl,)).fetchone(); print("ALL non-apparatus docs", vl, r); continue
    print(m, vl, con.execute(M,(m,vl)).fetchone())
