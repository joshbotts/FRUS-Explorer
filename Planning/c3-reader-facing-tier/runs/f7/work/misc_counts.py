import sqlite3
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
v77=[l.strip() for l in open("work/ea_vols_list.txt")]+['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08']
ph=",".join("?"*77)
print("docs in the 77 volumes (non-apparatus):",db.execute(f"select count(*) from document_cache where volume_id in ({ph}) and is_front_matter=0 and is_editorial_note=0",v77).fetchone()[0])
print("union 'public opinion poll' OR 'opinion survey':",db.execute(f"select count(*) from frus_documents f join document_cache d on d.rowid=f.rowid where frus_documents match ? and d.volume_id in ({ph}) and d.is_front_matter=0 and d.is_editorial_note=0",['"public opinion poll" OR "opinion survey"']+v77).fetchone()[0])
v5=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30']
print("docs in 5 public diplomacy vols (non-apparatus):",db.execute("select count(*) from document_cache where volume_id in (?,?,?,?,?) and is_front_matter=0 and is_editorial_note=0",v5).fetchone()[0])
print("docs in 74 EA vols (non-apparatus):",sum(int(l.split()[1]) for l in open("work/ea_vol_counts.txt")))
