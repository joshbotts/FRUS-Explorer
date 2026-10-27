import sqlite3, re, collections
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3v/../../c3/frus-copy-2026-10-25.db?mode=ro".replace("/c3v/../../","/"), uri=True)
EXC = "AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
CUBA = "(cuba OR cuban OR cubans OR havana OR habana)"
T = {
 "sugar_tariff_reciprocity": ("(sugar OR tariff OR reciprocity)", re.compile(r"\b(sugars?|tariffs?|reciprocity)\b",re.I), re.compile(r"\b(sugar(?:s|ed)?|tariffs?|reciproc(?:ity|al))\b",re.I)),
 "naval_base_terms": ('(guantanamo OR coaling OR marines OR "naval station" OR "naval base" OR "air base" OR "air bases")', re.compile(r"guant[aá]namo|coaling|marines|naval stations?|naval bases?|air bases?",re.I), re.compile(r"guant[aá]namo|coaling|marines?|naval[\s\-,().]+(?:stations?|bases?)|air[\s\-,().]+bases?",re.I)),
 "soviet_communist_missile_subversion": ("(soviet OR communist OR missile OR missiles OR subversion)", re.compile(r"soviets?|communists?|missiles?|subversion",re.I), re.compile(r"soviets?|communists?|missiles?|subver(?:sion|sive)",re.I)),
 "intervention_protectorate_platt": ('(intervention OR intervene OR protectorate OR "platt amendment")', re.compile(r"intervention|intervene|protectorate|platt amendment",re.I), re.compile(r"intervention|intervene[sd]?|intervening|protectorates?|platt[\s\-,().]+amendment",re.I)),
}
for name,(fts,st,tol) in T.items():
    n=s=o=0
    q=f"""select d.header||' '||coalesce(d.dateline,'')||' '||coalesce(d.source_note,'')||' '||d.body_text from frus_documents f join document_cache d on d.rowid=f.rowid
      join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where frus_documents match ? {EXC}"""
    for (txt,) in db.execute(q,(CUBA+" AND "+fts,)):
        t=re.sub(r"\s+"," ",txt); n+=1; s+=bool(st.search(t)); o+=bool(tol.search(t))
    print(name,"fts hits",n,"strict",s,"tolerant",o, f"strict {s}/{n}={s/n:.3f} tolerant {o}/{n}={o/n:.3f}")
