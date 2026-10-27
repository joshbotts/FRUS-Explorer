import sqlite3, re, json
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
db=sqlite3.connect(DB,uri=True)
cited=[tuple(l.rstrip('\n').split('\t')[:2]) for l in open('/Users/jbotts/frus-analysis/c3v/runs/v3/docs_list.tsv') if l.strip()]
# the find.py calls as logged (query, lo, hi, limit); the one with "$" raised an FTS5 syntax error and returned nothing
finds=[
 ('cuba AND (annex* OR possess* OR acquisition OR "key to the gulf")','1865','1895',25),
 ('cuba AND (annex* OR possess* OR acquisition OR "key to the gulf")','1865','1895',12),
 ('cuba AND sugar AND (reciprocity OR tariff OR duties OR commerce)','1875','1898',22),
 ('cuba AND ("naval stations" OR "coaling stations" OR platt OR "independence of cuba") AND (security OR defense OR protection OR safety)','1898','1912',20),
 ('guantanamo AND (naval OR coaling)','1898','1925',15),
 ('cuba AND ("american investments" OR "american capital" OR "american interests") AND sugar AND (million* OR billion*)','1910','1935',20),
 ('cuba AND intervention AND (policy OR principle) AND ("platt amendment" OR "third article" OR "treaty of relations")','1925','1936',14),
 ('cuba AND (bases OR "air bases") AND (strategic OR defense OR security) AND ("Guantanamo" OR "San Antonio")','1939','1950',12),
 ('cuba AND missiles AND ("balance of power" OR "strategic balance" OR "political" ) AND ("no great difference" OR "strategic" )','1962-10-14','1962-10-30',15),
 ('cuba AND missiles','1962-10-16','1962-10-17',10),
 ('cuba AND ("a missile is a missile" OR "geopolitical" OR "politically")','1962-10-16','1962-10-19',6),
 ('cuba AND cuban AND (threat OR subversion OR "national security" OR hemisphere)','1981','1989',14),
 ('cuba AND (investment* OR sugar) AND ("national security" OR strategic OR defense) AND (stability OR stable)','1950','1959',14),
 ('cuba AND ("sugar act" OR "sugar quota") AND (castro OR revolution)','1959','1961',8),
 ('cuba AND (burden OR liability OR drain) AND (soviet OR russians) AND (economy OR economic OR subsidy)','1964','1981',12),
 ('cuba AND (normalization OR "normalizing") AND (embargo OR trade) AND (interest* OR benefit*)','1974','1981',12),
 ('cuba AND sugar AND (war OR defense OR submarines OR shipping) AND ("entire" OR "purchase")','1941','1945',8),
 ('cuba AND (sugar OR investments) AND (intervention OR intervene) AND (property OR interests)','1915','1925',6),
 ('cuba AND machado AND (sugar OR investments OR property) AND (intervention OR chaos OR anarchy)','1933','1934',6),
]
SQL="""SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
 LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
 WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0
 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
 AND dd.date_iso >= ? AND dd.date_iso < ? ORDER BY bm25(frus_documents)"""
within_limit={p:[] for p in cited}; any_rank={p:[] for p in cited}
for qi,(q,lo,hi,lim) in enumerate(finds):
    try: rows=db.execute(SQL,(q,lo,hi)).fetchall()
    except Exception as e: print("QUERY ERROR",qi,q[:50],e); continue
    pos={r:i for i,r in enumerate(rows)}
    for p in cited:
        if p in pos:
            any_rank[p].append((qi,pos[p]+1,len(rows)))
            if pos[p]<lim: within_limit[p].append((qi,pos[p]+1))
# the heading/dateline queries (no limit on the decade one; the pre-1895 one had LIMIT 60 ordered by date)
H1="""SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH '{header dateline}:(cuba OR cuban OR havana OR habana OR virginius)' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso < '1895' ORDER BY dd.date_iso LIMIT 60"""
H2="""SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH '{header dateline} : (cuba OR cuban OR havana OR habana OR guantanamo)' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"""
h1=set(db.execute(H1).fetchall()); h2=set(db.execute(H2).fetchall())
# the broad Scope B predicate (a count query in the log, no document list printed, but a MATCH the session logged)
B=set(db.execute("""SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '(cuba OR cuban OR cubans OR havana OR habana)' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')""").fetchall())
setA={tuple(l.rstrip('\n').split('\t')[:2]) for l in open('setA.tsv')}
# nsec.py style query (national security AND cuba, pre-1945) and the 1981% volume-count query (volume level only)
print(f"{'pair':34} {'find(within LIMIT)':22} {'find(any rank)':18} {'hdr<1895':9} {'hdr-dec':8} {'ScopeA':7} {'ScopeB':7}")
for p in cited:
    print(f"{p[0]+'/'+p[1]:34} {str([(a,b) for a,b in within_limit[p]]):22} {str([(a,b,c) for a,b,c in any_rank[p]])[:60]:18} {str(p in h1):9} {str(p in h2):8} {str(p in setA):7} {str(p in B):7}")
