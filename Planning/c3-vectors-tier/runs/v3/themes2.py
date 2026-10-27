import sqlite3, collections, json
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
CUBA = "(cuba OR cuban OR cubans OR havana OR habana)"
groups = {
 "ALL": "",
 "sugar_tariff_reciprocity": " AND (sugar OR tariff OR reciprocity)",
 "naval_base_terms": " AND (guantanamo OR coaling OR marines OR \"naval station\" OR \"naval base\" OR \"air base\" OR \"air bases\")",
 "soviet_communist_missile_subversion": " AND (soviet OR communist OR missile OR missiles OR subversion)",
 "intervention_protectorate_platt": " AND (intervention OR intervene OR protectorate OR \"platt amendment\")",
 "yellow_fever": " AND \"yellow fever\"",
 "claims_expropriation": " AND (claims OR expropriation OR confiscation)",
 "national_security_phrase": " AND \"national security\"",
 "prosperity": " AND prosperity",
}
EXC = "AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
out = {}
base_dec = collections.Counter()
for (dec,n) in db.execute("select substr(dd.date_iso,1,3)||'0s', count(*) from document_cache d join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where 1=1 "+EXC+" group by 1"):
    base_dec[dec]=n
for g,expr in groups.items():
    q = f"""select substr(dd.date_iso,1,3)||'0s' dec, d.volume_id, count(*) from frus_documents f join document_cache d on d.rowid=f.rowid
      join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id
      where frus_documents match ? {EXC} group by dec, d.volume_id"""
    per = collections.defaultdict(lambda: collections.Counter())
    for dec,v,n in db.execute(q,(CUBA+expr,)):
        per[dec][v]+=n
    out[g]={dec:{"n":sum(c.values()),"top":c.most_common(1)[0]} for dec,c in per.items()}
json.dump({"groups":out,"base":base_dec},open("themes2.json","w"),indent=1)
decs=["1860s","1870s","1880s","1890s","1900s","1910s","1920s","1930s","1940s","1950s","1960s","1970s","1980s"]
print("dec | dated docs | cuba docs (per1000; top vol share) | "+" | ".join(list(groups)[1:]))
for dec in decs:
    a=out["ALL"].get(dec,{"n":0,"top":("",0)})
    row=f"{dec} | {base_dec[dec]} | {a['n']} ({1000*a['n']/base_dec[dec]:.1f}; {a['top'][0]} {a['top'][1]/max(a['n'],1):.2f})"
    for g in list(groups)[1:]:
        x=out[g].get(dec,{"n":0})["n"]
        row+=f" | {x} ({100*x/max(a['n'],1):.0f}%)"
    print(row)
