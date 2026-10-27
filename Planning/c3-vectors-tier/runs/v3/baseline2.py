import sqlite3, collections
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
EXC = "AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
base={}
for r in db.execute("select substr(dd.date_iso,1,3)||'0s', count(*) from document_cache d join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where 1=1 "+EXC+" group by 1"): base[r[0]]=r[1]
G={"sugar_tariff_reciprocity":"(sugar OR tariff OR reciprocity)","naval_base_terms":'(guantanamo OR coaling OR marines OR "naval station" OR "naval base" OR "air base" OR "air bases")',"soviet_communist_missile_subversion":"(soviet OR communist OR missile OR missiles OR subversion)","intervention_protectorate_platt":'(intervention OR intervene OR protectorate OR "platt amendment")'}
for name,fts in G.items():
    c=collections.Counter()
    for dec,n in db.execute(f"select substr(dd.date_iso,1,3)||'0s', count(*) from frus_documents f join document_cache d on d.rowid=f.rowid join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where frus_documents match ? {EXC} group by 1",(fts,)): c[dec]=n
    print(name, {k:f"{c[k]}/{base[k]}={100*c[k]/base[k]:.1f}%" for k in ["1860s","1870s","1880s","1890s","1900s","1910s","1920s","1930s","1940s","1950s","1960s","1970s","1980s"]})
