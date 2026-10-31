import sqlite3, re, json
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con=sqlite3.connect(DB, uri=True)
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
BASE="FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0"
def run(match, extra="", order="", limit=None, ed2=True):
    sql="SELECT c.volume_id, c.document_id "+BASE+(" AND c.volume_id NOT IN "+ED2 if ed2 else "")+extra+(" ORDER BY "+order if order else "")+(" LIMIT %d"%limit if limit else "")
    return [(v,d) for v,d in con.execute(sql,(match,)).fetchall()]
BM="round(bm25(frus_documents,0,0,0,5,1,1,1),1)"
queries={
 "Q_corrupt_set":      run("corrupt*"),
 "Q_brib_set":         run("brib*"),
 "Q_header_corrupt":   run("header:corrupt* OR header:brib*", ed2=False),
 "Q_china_aid25":      run("(corrupt* OR brib*) AND (aid OR assist*)", " AND c.volume_id IN ('frus1947v07','frus1948v08','frus1948v07','frus1949v09','frus1946v10','frus1944v06','frus1945v07','frus1943China')", "round(bm25(frus_documents,0,0,0,10,1,1,1),1)", 25, ed2=False),
 "Q_china_policy15":   run("corrupt* AND (polici OR decis* OR Congress) AND (aid OR assist*)", " AND c.volume_id IN ('frus1947v07','frus1948v08','frus1948v07','frus1949v09','frus1949v08','frus1946v10')", BM, 15, ed2=False),
 "Q_vietnam25":        run("corrupt*", " AND c.volume_id IN ('frus1958-60v01','frus1961-63v01','frus1961-63v04','frus1964-68v04','frus1964-68v05','frus1964-68v06','frus1969-76v07','frus1969-76v08','frus1969-76v10')", BM, 25, ed2=False),
 "Q_lockheed_mix60":   run("(Lockheed AND (brib* OR payment*)) OR \"questionable payment*\" OR \"illicit payment*\" OR \"improper payment*\" OR \"foreign corrupt practic*\"", "", "d.date_iso", 60, ed2=False),
 "Q_korea_nica24":     run("corrupt*", " AND c.volume_id IN ('frus1961-63v22','frus1977-80v15') AND c.document_id LIKE 'd%'", BM, 24, ed2=False),
 "Q_lockheed43":       run("Lockheed AND (brib* OR payoff* OR payment*)"),
 "Q_church24":         run("\"Church Subcommittee\" OR \"Multinational Subcommittee\" OR \"Subcommittee on Multinational Corporations\""),
 "Q_fcpa4":            run("\"foreign corrupt practic*\""),
 "Q_personnel76":      run("corrupt* AND (\"American personnel\" OR \"U.S. personnel\" OR \"American officials\")"),
 "Q_blackmarket28":    run("\"black market\" AND corrupt*"),
 "Q_inclined_bribe":   run("\"inclined to bribe\"", " AND c.volume_id='frus1977-80v19'", ed2=False),
}
for k,v in queries.items(): print(k, len(v))
heads=set()
for l in open("/Users/jbotts/frus-analysis/c3s/runs/s8/raw/heads_hits.txt"):
    heads.add(l.split(" | ")[0].strip())
print("heads_hits volumes:",sorted(heads))
cited=[("frus1947v07","d628"),("frus1947v07","d582"),("frus1948v07","d322"),("frus1958-60v01","d135"),("frus1958-60v01","d267"),("frus1964-68v05","d395"),("frus1964-68v06","d31"),("frus1961-63v22","d202"),("frus1961-63v22","d221"),("frus1961-63v22","d297"),("frus1969-76ve09p2","d122"),("frus1969-76ve09p2","d152"),("frus1969-76ve09p2","d155"),("frus1969-76ve09p2","d161"),("frus1969-76ve15p2","d292"),("frus1969-76ve15p2","d293"),("frus1969-76ve12","d218"),("frus1969-76ve12","d219"),("frus1969-76ve12","d227"),("frus1969-76ve09p1","d50"),("frus1977-80v15","d68"),("frus1977-80v15","d80"),("frus1977-80v15","d83"),
       ("frus1947v07","d617"),("frus1964-68v06","d134"),("frus1964-68v04","d215"),("frus1947v07","d583"),("frus1948v07","d407")]
labels={("frus1947v07","d617"):"(quoted, uncited)",("frus1964-68v06","d134"):"(quoted, uncited)",("frus1964-68v04","d215"):"(paraphrased, uncited)",("frus1947v07","d583"):"(collection only)",("frus1948v07","d407"):"(collection only)"}
print("\npair | queries returning it")
summary={}
for p in cited:
    hits=[k for k,v in queries.items() if p in v]
    summary[p]=hits
    print(f"{p[0]}/{p[1]} {labels.get(p,'')}: {hits if hits else 'NONE'}")
# position of d155 in the lockheed_mix60 printed list
L=queries["Q_lockheed_mix60"]
print("\nd155 in Q_lockheed_mix60 printed list:", ("frus1969-76ve09p2","d155") in L, "position", [i for i,x in enumerate(L) if x==("frus1969-76ve09p2","d155")], "list dates span:", con.execute("SELECT MIN(d.date_iso), MAX(d.date_iso) FROM document_dates d WHERE (d.volume_id,d.document_id) IN (VALUES %s)"%",".join("('%s','%s')"%x for x in L)).fetchone())
print("d155 in Q_lockheed43:", ("frus1969-76ve09p2","d155") in queries["Q_lockheed43"])
print("d155 matches corrupt*/brib*:", ("frus1969-76ve09p2","d155") in queries["Q_corrupt_set"], ("frus1969-76ve09p2","d155") in queries["Q_brib_set"])
json.dump({"%s/%s"%p:v for p,v in summary.items()}, open("s7_reach.json","w"), indent=1)
