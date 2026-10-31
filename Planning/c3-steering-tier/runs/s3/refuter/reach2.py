import json, sqlite3, time
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"; RUN="/Users/jbotts/frus-analysis/c3s/runs/s3/"
con=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
cited=[tuple(l.strip().split("/")) for l in open(RUN+"cited.txt") if l.strip()]
Q={"family MATCH (M4/M5 scope set)":"corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl",
 "family MATCH without grafter (top_bm25 / header runs)":"corrupt* OR bribe OR briberi OR graft OR kickback OR embezzl",
 "header: query":"header:(corrupt* OR bribe OR briberi OR graft OR kickback OR embezzl OR lockhe)",
 "payments phrase MATCH (M7, logged after the neighbour list)":'"improper payment" OR "illicit payment" OR "questionable payment"',
 "d155 targeted plural phrases (logged after the neighbour list)":'"improper payments" OR "illicit payments"',
 "foreign corrupt practic* (M17)":'"foreign corrupt practic*"',
 "oecd AND (bribe OR briberi) (M17)":"oecd AND (bribe OR briberi)",
 "anti corrupt* (M18)":'"anti corrupt*"',
 "church subcommittee/committee (M19)":'"church subcommittee" OR "church committee"',
 "control \"Department of State\" (M9)":'"Department of State"'}
sets={}
for name,m in Q.items():
    t=time.time(); rows=con.execute("SELECT volume_id, document_id FROM frus_documents WHERE frus_documents MATCH ?",(m,)).fetchall()
    sets[name]=set(rows); print("%-62s %7d rows  %5.1fs"%(name,len(rows),time.time()-t), flush=True)
top80=[tuple(l.split("|")[:2]) for l in open(RUN+"top_bm25.txt") if "|" in l]
hh=[tuple(l.split("|")[:2]) for l in open(RUN+"header_hits.txt") if "|" in l]
share=[(r[0],r[1]) for r in json.load(open(RUN+"share_sample.json"))["sample"]]
pay=[tuple(l.split()[:2]) for l in open(RUN+"payments.txt") if l.startswith("frus")]
neigh={a:[tuple(r[1]) for r in rows] for a,rows in json.load(open(RUN+"vectors_out.json"))["neighbours"].items()}
print("\ntop_bm25 rows",len(top80),"| header hits",len(hh),"| share sample",len(share),"| payments census",len(pay))
for v,d in cited:
    hits=[n for n,s in sets.items() if (v,d) in s]
    printed=[]
    if (v,d) in top80: printed.append("top_bm25 #%d"%(top80.index((v,d))+1))
    if (v,d) in hh: printed.append("header_hits")
    if (v,d) in share: printed.append("share_sample")
    if (v,d) in pay: printed.append("payments census (logged after the neighbour list)")
    via=[a for a,l in neigh.items() if (v,d) in l]
    print("%s/%s\n   returned by: %s\n   printed sets: %s | anchor: %s | surfaced in neighbour lists of: %s"%(v,d,hits,printed,"%s/%s"%(v,d) in neigh,via))
fam=sets["family MATCH (M4/M5 scope set)"]
print("\ncited in the family MATCH:",sum(1 for p in cited if p in fam),"of",len(cited),"| not:",[p for p in cited if p not in fam])
dos=sets['control "Department of State" (M9)']
vols=set(v for v,d in dos); allv=set(r[0] for r in con.execute("SELECT DISTINCT volume_id FROM document_cache"))
print("M9: volumes with the control phrase",len(vols),"of",len(allv),"| missing:",sorted(allv-vols),"| impossible string:",con.execute("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ'").fetchone())
print("M17 FCPA docs, volumes:",len(sets["foreign corrupt practic* (M17)"]),len(set(v for v,d in sets["foreign corrupt practic* (M17)"])),"| M18 anti corrupt* docs:",len(sets["anti corrupt* (M18)"]),"| klepto vocab:",con.execute("SELECT COUNT(*) FROM frus_documents_vocab WHERE term LIKE 'klepto%'").fetchone())
print("M19 withheld:",con.execute("""SELECT COUNT(*), SUM(c.body_text LIKE '%not declassified%') FROM (SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
 WHERE frus_documents MATCH 'corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')) h
 JOIN document_dates t ON t.volume_id=h.volume_id AND t.document_id=h.document_id JOIN document_cache c ON c.volume_id=h.volume_id AND c.document_id=h.document_id WHERE t.date_iso >= '1969-01-20'""").fetchone())
print("M8 decades:",con.execute("""SELECT substr(t.date_iso,1,3)||'0s', COUNT(*), SUM(h.document_id IS NOT NULL) FROM document_cache c JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id
 LEFT JOIN (SELECT volume_id, document_id FROM frus_documents WHERE frus_documents MATCH 'corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl') h ON h.volume_id=c.volume_id AND h.document_id=c.document_id
 WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND t.date_iso IS NOT NULL AND substr(t.date_iso,1,3) IN ('193','196','197','198','199') GROUP BY 1""").fetchall())
