# per-volume document counts (non-apparatus) for FTS families over R and I, with controls
import sqlite3,sys,json
sys.path.insert(0,'.'); from scopevols import R,I
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
F={'POS_DeptState':'"Department of State"','NEG':'ZZZ_IMPOSSIBLE_ZZZ',
 'propaganda':'propaganda','psychological':'psycholog','usia_usis':'usia OR usi',
 'info_program':'"information program"','image_US':'"image of the United States"',
 'prestige':'prestig','public_diplomacy':'"public diplomacy"','cultural_exchange':'"cultural exchange"',
 'VOA':'"Voice of America"','soft_power':'"soft power"','psywar':'"psychological warfare"',
 'hearts_minds':'"hearts and minds"','asian_mind':'"Asian mind" OR "Oriental mind" OR "Asian mentality" OR "Oriental mentality"'}
SQL="""SELECT d.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (%s) GROUP BY d.volume_id"""
vols=R+I; ph=','.join('?'*len(vols))
tot={v:c.execute("SELECT COUNT(*) FROM document_cache WHERE volume_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,)).fetchone()[0] for v in vols}
res={}
for k,q in F.items():
    res[k]={v:n for v,n in c.execute(SQL%ph,[q]+vols)}
json.dump({'tot':tot,'res':res,'F':F,'SQL':SQL},open('scan_families.json','w'),indent=1)
hdr=['vol','N']+list(F)
print('\t'.join(hdr))
for v in vols: print('\t'.join([v,str(tot[v])]+[str(res[k].get(v,0)) for k in F]))
print('\t'.join(['R_total',str(sum(tot[v] for v in R))]+[str(sum(res[k].get(v,0) for v in R)) for k in F]))
print('\t'.join(['I_total',str(sum(tot[v] for v in I))]+[str(sum(res[k].get(v,0) for v in I)) for k in F]))
