import sqlite3,re,collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open("scope_vols.txt")]
PDV=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30','frus1955-57v09','frus1961-63v25']
REG=[v for v in vols if v not in PDV]
print("REGIONAL volumes:",len(REG),"; info/PD volumes:",len(PDV))
ph=lambda L:",".join("?"*len(L))
BASE="d.is_front_matter=0 AND d.is_editorial_note=0"
tot=db.execute("select count(*) from document_cache d where volume_id in (%s) and %s"%(ph(REG),BASE),REG).fetchone()[0]
print("SQL: select count(*) from document_cache d where volume_id in (REG) and is_front_matter=0 and is_editorial_note=0 ->",tot)
FAM='(USIA OR USIS OR "Voice of America" OR "information program" OR "psychological warfare" OR "psychological strategy" OR "United States Information")'
Q="SELECT d.volume_id,d.document_id,dd.date_iso FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND "+BASE
print("SQL (family A):",Q%"REG...", "MATCH",FAM)
rows=db.execute(Q%ph(REG),[FAM]+REG).fetchall()
print("family A hits in REG:",len(rows),"of",tot)
for name,q in [("positive control 'Department of State'",'"Department of State"'),("negative control ZZZ_IMPOSSIBLE_ZZZ","ZZZ_IMPOSSIBLE_ZZZ"),('"soft power"','"soft power"'),('soft AND power','soft AND power'),('"public diplomacy"','"public diplomacy"'),('"cultural diplomacy"','"cultural diplomacy"')]:
    n=len(db.execute(Q%ph(REG),[q]+REG).fetchall())
    print("REG",name,"->",n)
# decade shape
dec_tot=collections.Counter(); dec_hit=collections.Counter(); dec_vol=collections.defaultdict(collections.Counter)
for v,dn,dt in db.execute("select d.volume_id,d.document_id,dd.date_iso from document_cache d left join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where d.volume_id in (%s) and %s"%(ph(REG),BASE),REG):
    if dt: dec_tot[dt[:3]+"0s"]+=1
undated=0
for v,dn,dt in rows:
    if dt: dec_hit[dt[:3]+"0s"]+=1; dec_vol[dt[:3]+"0s"][v]+=1
    else: undated+=1
print("family A undated hits:",undated)
print("decade | hits | dated non-apparatus docs in REG | per 1,000 | top volume (share)")
for d in sorted(dec_tot):
    h=dec_hit[d]; t=dec_tot[d]; tv=dec_vol[d].most_common(1)
    print("%s | %d | %d | %.0f | %s"%(d,h,t,1000*h/t,("%s %d of %d"%(tv[0][0],tv[0][1],h)) if tv else "-"))
# false friend: 'audience'
other=[r[0] for r in db.execute("select distinct volume_id from document_cache where (volume_id glob 'frus194[89]*' or volume_id glob 'frus195*' or volume_id glob 'frus196*' or volume_id glob 'frus197*') and volume_id not like '%Ed2' ")]
CTRL=[v for v in other if v not in vols]
ctot=db.execute("select count(*) from document_cache d where volume_id in (%s) and %s"%(ph(CTRL),BASE),CTRL).fetchone()[0]
print("control volumes (1948-80 non-scope):",len(CTRL),"docs",ctot)
for term in ["audience OR audiences","USIS OR USIA","propaganda"]:
    a=len(db.execute(Q%ph(REG),[term]+REG).fetchall()); c=len(db.execute(Q%ph(CTRL),[term]+CTRL).fetchall())
    print("FALSE-FRIEND '%s': REG %d of %d (%.1f per 1,000) vs control %d of %d (%.1f per 1,000)"%(term,a,tot,1000*a/tot,c,ctot,1000*c/ctot))
