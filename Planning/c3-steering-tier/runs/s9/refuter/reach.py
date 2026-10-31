import sqlite3
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con=sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
pairs=[('frus1943China','d202'),('frus1947v07','d292'),('frus1948v07','d506'),('frus1950v06','d831'),('frus1958-60v01','d179'),('frus1964-68v05','d258'),('frus1964-68v06','d16'),('frus1969-76ve15p2','d292'),('frus1969-76ve15p2','d293'),('frus1969-76ve09p2','d155'),('frus1969-76ve12','d218'),('frus1969-76ve12','d222'),('frus1969-76ve12','d224'),('frus1969-76ve12','d227'),('frus1969-76v31','d140'),('frus1977-80v03','d266'),('frus1977-80v03','d310'),('frus1977-80v13','d84'),('frus1977-80v13','d92'),('frus1977-80v13','d94'),('frus1875v01','d199')]
ED2="AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
NA="AND c.is_front_matter=0 AND c.is_editorial_note=0"
CHINA="AND c.volume_id IN ('frus1943China','frus1944v06','frus1945v07','frus1946v10','frus1947v07','frus1948v07','frus1948v08','frus1949v08','frus1949v09')"
VN="AND (c.volume_id LIKE 'frus1964-68v0%' OR c.volume_id IN ('frus1958-60v01','frus1961-63v01','frus1961-63v02','frus1961-63v03','frus1961-63v04') OR c.volume_id LIKE 'frus1969-76v0%')"
queries={
 "L51 S": ("corrupt* OR brib* OR graft OR embezzl* OR kickback* OR \"illicit payment\"", NA+" "+ED2),
 "L7 corrupt*": ("corrupt*", NA),
 "L24 OR-5": ("corrupt* OR brib* OR graft OR embezzl* OR kickback*", NA),
 "L26 header": ("header:(corrupt* OR brib* OR graft OR embezzl* OR \"illicit payment\" OR \"question payment\" OR lockheed OR kickback*)", "AND c.is_front_matter=0"),
 "L27 NEAR": ("NEAR(lockheed (brib* OR payment* OR scandal OR corrupt*), 20) OR \"illicit payment\" OR \"question payment\" OR \"foreign corrupt practic\" OR \"tongsun park\"", NA),
 "L28 lockheed-AND": ("(lockheed AND (brib* OR scandal OR payoff*)) OR \"illicit payment\" OR \"question payment\" OR \"foreign corrupt practic\" OR \"tongsun park\"", NA),
 "L31 China aid": ("(corrupt* OR graft) AND (aid OR assist*)", CHINA+" "+NA),
 "L33 Vietnam aid": ("corrupt* AND (aid OR assist* OR pressur* OR leverag*)", VN+" "+NA),
 "L10 illicit payment": ("\"illicit payment\"", NA),
 "L15 tongsun park": ("\"tongsun park\"", NA),
 "L16 brib*": ("brib*", NA),
 "L22 lockheed": ("lockheed", NA),
 "L68 koreagate": ("koreagate", NA+" "+ED2),
 "L71 tanaka lockheed": ("tanaka AND lockheed", NA+" "+ED2),
 "L72 lockheed scandal": ("lockheed AND (brib* OR payoff* OR scandal OR \"illicit payment\")", NA+" "+ED2),
 "L73 northrop": ("northrop AND (brib* OR payment*)", NA+" "+ED2),
 "L74 FCPA": ("\"foreign corrupt practices act\"", NA+" "+ED2),
 "L12 corrupt practic": ("\"corrupt practic\"", NA),
}
hits={k:set() for k in queries}
for k,(m,filt) in queries.items():
    try:
        rows=con.execute(f"SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? {filt}", (m,)).fetchall()
        hits[k]=set(rows)
    except Exception as e:
        print("QUERY ERROR", k, "->", e); hits[k]=set()
print("query sizes:", {k:len(v) for k,v in hits.items()})
print()
for p in pairs:
    found=[k for k in queries if p in hits[k]]
    print(f"{p[0]}/{p[1]:5s} reached by {len(found):2d} logged queries: {found}")
