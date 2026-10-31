from h import *
c=conn()
SQL="SELECT COUNT(*), COUNT(DISTINCT f.volume_id), MIN(d.volume_id), MAX(d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ?"
print(SQL)
for t in ['"Department of State"','ZZZ_IMPOSSIBLE_ZZZ','"soft power"','"public diplomacy"','"Boxer indemnity"','"indemnity" AND "education"','"remission" AND "indemnity" AND "students"','"cultural relations"','"Division of Cultural Relations"','"educational exchange"','"Voice of America"']:
    print(t, c.execute(SQL,(t,)).fetchone())
# Pre-1945 East Asia: volumes with year <1945 and Chinese/Japanese education terms
SQL2="SELECT f.volume_id, f.document_id, substr(replace(d.header,char(10),' '),1,100), d.dateline FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ? ORDER BY bm25(frus_documents) LIMIT 12"
q='("Boxer indemnity" OR "indemnity" ) AND (students OR education OR educational OR university OR scholarships) AND China'
print(SQL2,q)
for r in c.execute(SQL2,(q,)): print(r)
