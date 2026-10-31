# coreset.py: builds the core set C (written to raw/coreset.tsv)
# Regional volumes = scope_volumes.txt minus the 9 global volumes below; global volumes additionally require an Asia term.
import sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open('scope_volumes.txt') if l.strip()]
GLOBAL=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1955-57v09','frus1961-63v25','frus1969-76v38p2','frus1977-80v30','frus1952-54v02p2','frus1950-55Intel']
REG=[v for v in vols if v not in GLOBAL]
FAM='(usia OR usi OR "information program" OR "psychological strategy" OR "psychological warfare" OR "cultural exchange")'
ASIA='(asia OR asian OR "far east" OR japan OR japanese OR korea OR vietnam OR "viet nam" OR philippines OR indonesia OR thailand OR laos OR cambodia OR burma OR china OR chinese OR taiwan OR australia OR pacific)'
q="SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id IN (%s)"
def ql(vs): return ",".join("'%s'"%v for v in vs)
a=con.execute(q%ql(REG),(FAM,)).fetchall()
b=con.execute(q%ql(GLOBAL),(FAM+' AND '+ASIA,)).fetchall()
print('SQL:',q%'<volumes>','MATCH regional=',FAM,' MATCH global=',FAM+' AND '+ASIA)
print('regional',len(a),'global',len(b))
s=sorted(set(a+b))
open('raw/coreset.tsv','w').write('\n'.join(v+'\t'+d for v,d in s)+'\n')
print('core set',len(s),'volumes',len(set(v for v,d in s)))
# denominators
n_reg=con.execute("SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id IN (%s)"%ql(REG)).fetchone()[0]
print('regional denominator (non-apparatus docs in regional volumes):',n_reg, 'regional volumes',len(REG))
