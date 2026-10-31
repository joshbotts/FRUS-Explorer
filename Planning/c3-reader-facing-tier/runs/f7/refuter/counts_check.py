import sqlite3,json,collections
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
db=sqlite3.connect(f"file:{DB}?mode=ro",uri=True)
W="/Users/jbotts/frus-analysis/c3f/runs/f7/work/"
ea=[l.strip() for l in open(W+"ea_vols_list.txt") if l.strip()]
pd3=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08']
pd5=pd3+['frus1969-76v38p2','frus1977-80v30']
v79=ea+pd5; v77=ea+pd3
print("74 EA volumes listed:",len(ea),"unique:",len(set(ea)))
man=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
mids={v["volumeId"] for v in man}
print("all 79 in manifest:",all(v in mids for v in v79), [v for v in v79 if v not in mids])
inidx={r[0] for r in db.execute("select distinct volume_id from document_cache")}
print("all 79 in index:",all(v in inidx for v in v79), "index volumes:",len(inidx))
def cnt(vols):
    ph=",".join("?"*len(vols))
    return db.execute(f"select count(*) from document_cache where volume_id in ({ph}) and is_front_matter=0 and is_editorial_note=0",vols).fetchone()[0]
print("HEADLINE 2: non-apparatus docs in 79 volumes:",cnt(v79)," (74 EA:",cnt(ea),"; 5 PubDip:",cnt(pd5),"; 77:",cnt(v77),")")
def match_cnt(q,vols):
    ph=",".join("?"*len(vols))
    return db.execute(f"select count(*),count(distinct d.volume_id) from frus_documents f join document_cache d on d.rowid=f.rowid where frus_documents match ? and d.volume_id in ({ph}) and d.is_front_matter=0 and d.is_editorial_note=0",[q]+vols).fetchone()
print("HEADLINE 3: 'soft power' in 79:",match_cnt('"soft power"',v79))
print("  'soft power' whole index (non-apparatus):",db.execute("select count(*) from frus_documents f join document_cache d on d.rowid=f.rowid where frus_documents match '\"soft power\"' and d.is_front_matter=0 and d.is_editorial_note=0").fetchone())
print("  'soft power' whole index incl apparatus:",db.execute("select count(*) from frus_documents where frus_documents match '\"soft power\"'").fetchone())
fam='"oriental mind" OR "asian mind" OR "asian psychology" OR "psychology of asians" OR "oriental psychology" OR "asiatic mind"'
print("HEADLINE 5: oriental-mind family in 79:",match_cnt(fam,v79))
ph=",".join("?"*len(v79))
rows=db.execute(f"select d.volume_id,d.document_id from frus_documents f join document_cache d on d.rowid=f.rowid where frus_documents match ? and d.volume_id in ({ph}) and d.is_front_matter=0 and d.is_editorial_note=0 order by 1,2",[fam]+v79).fetchall()
print("  pairs:",[f"{v}/{d}" for v,d in rows])
# 17/15 classification file
cls=[l.rstrip("\n").split("\t") for l in open(W+"belief_classes.tsv") if l.strip()]
print("  belief_classes.tsv rows:",len(cls),"classes:",collections.Counter(c[1] if len(c)>1 else '?' for c in cls))
# controls
print("CONTROL dept of state in 77:",match_cnt('"department of state"',v77))
print("CONTROL ZZZ in 79:",match_cnt('"ZZZ_IMPOSSIBLE_ZZZ"',v79))
print("opinion-poll union in 77:",match_cnt('"public opinion poll" OR "opinion survey"',v77))
war=['frus1941v04','frus1942China','frus1942v01','frus1943China','frus1943v03','frus1944v05','frus1944v06','frus1945v06','frus1945v07']
print("wartime 9 vols docs:",cnt(war)," OWI phrase:",match_cnt('"office of war information"',war)," owi:",match_cnt('owi',war))
# 202/143 external citations in the 5 PubDip vols
ph5=",".join("?"*5)
print("ext_cit PubDip5 rows/docs:",db.execute(f"select count(*),count(distinct volume_id||'/'||document_id) from external_citations where volume_id in ({ph5})",pd5).fetchone())
print("ext_cit PubDip5 rows/docs non-apparatus only:",db.execute(f"select count(*),count(distinct e.volume_id||'/'||e.document_id) from external_citations e join document_cache d on d.volume_id=e.volume_id and d.document_id=e.document_id where e.volume_id in ({ph5}) and d.is_front_matter=0 and d.is_editorial_note=0",pd5).fetchone())
ph74=",".join("?"*len(ea))
print("ext_cit EA74 rows/docs:",db.execute(f"select count(*),count(distinct volume_id||'/'||document_id) from external_citations where volume_id in ({ph74})",ea).fetchone())
print("top lots PubDip5:",db.execute(f"select lot_file_norm,count(*),count(distinct document_id) from external_citations where volume_id in ({ph5}) and lot_file_norm is not null and lot_file_norm<>'' group by 1 order by 2 desc limit 4",pd5).fetchall())
print("top lots EA74:",db.execute(f"select lot_file_norm,count(*),count(distinct volume_id||'/'||document_id) from external_citations where volume_id in ({ph74}) and lot_file_norm is not null and lot_file_norm<>'' group by 1 order by 2 desc limit 3",ea).fetchall())
print("min date pointed-at channel:",db.execute("select min(substr(dd.date_iso,1,10)) from external_citations e join document_dates dd on dd.volume_id=e.volume_id and dd.document_id=e.document_id where dd.date_iso is not null and dd.date_iso<>''").fetchone())
# decade table
den=collections.Counter()
for y,n in db.execute(f"select substr(dd.date_iso,1,3)||'0s',count(*) from document_cache d join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where d.is_front_matter=0 and d.is_editorial_note=0 and d.volume_id in ({ph}) group by 1",v79):
    if y: den[y]=n
q='"information agency" OR usis OR usia OR "information service" OR "voice of america" OR "information program"'
hit=collections.Counter();byvol=collections.defaultdict(collections.Counter)
for v,y in db.execute(f"select d.volume_id,substr(dd.date_iso,1,3)||'0s' from frus_documents f join document_cache d on d.rowid=f.rowid join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0 and d.volume_id in ({ph})",[q]+v79):
    if y: hit[y]+=1;byvol[y][v]+=1
for y in sorted(den):
    top=byvol[y].most_common(1)
    print(f"DECADE {y}: {hit[y]} of {den[y]} = {1000*hit[y]/den[y]:.1f}/1000; 1 in {den[y]/hit[y] if hit[y] else 0:.1f}; top {top}")
# date span of documents in the 79 volumes
print("date span 79 vols (document_dates):",db.execute(f"select min(date_iso),max(date_iso) from document_dates dd join document_cache d on d.volume_id=dd.volume_id and d.document_id=dd.document_id where d.volume_id in ({ph}) and d.is_front_matter=0 and d.is_editorial_note=0 and dd.date_iso is not null and dd.date_iso<>''",v79).fetchone())
print("manifest year span 79 vols:",min(v["dateRange"]["earliest"][:4] for v in man if v["volumeId"] in v79),max(v["dateRange"]["latest"][:4] for v in man if v["volumeId"] in v79))
# false-friend ratios: usis
yr={v["volumeId"]:int(v["dateRange"]["earliest"][:4]) for v in man}
ctrl=sorted(v for v in yr if yr[v]>=1946 and v not in set(v79) and not v.endswith("Ed2") and "mSupp" not in v)
print("control volumes:",len(ctrl),"docs:",cnt(ctrl))
for t in ["usis","prestige","image","propaganda","department of state"]:
    a=match_cnt(f'"{t}"',v79)[0]; b=match_cnt(f'"{t}"',ctrl)[0]
    print(f"  {t}: on {a} ({1000*a/cnt(v79):.1f}) ctrl {b} ({1000*b/cnt(ctrl):.1f}) ratio {(a/cnt(v79))/(b/cnt(ctrl)):.2f}")
