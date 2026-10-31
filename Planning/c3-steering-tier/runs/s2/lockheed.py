# census of MATCH 'lockheed AND (bribe OR bribery OR payments OR scandal OR corruption)': literal test + referent test (bribe/briber* within the text)
import sqlite3, re, collections
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL = ("SELECT c.volume_id, c.document_id, t.date_iso, c.header||' '||COALESCE(c.dateline,'')||' '||COALESCE(c.source_note,'')||' '||c.body_text "
       "FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id "
       "WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') ORDER BY c.volume_id, c.document_id")
print("SQL:", SQL)
rows = con.execute(SQL, ("lockheed AND (bribe OR bribery OR payments OR scandal OR corruption)",)).fetchall()
L = re.compile(r"\bLockheed\b", re.I); STRICT = re.compile(r"\b(bribe|bribes|bribery|scandal|corruption|payments)\b", re.I)
REF = re.compile(r"\bbrib\w*|\bscandals?\b|\bcorrupt\w*|questionable payments|payoffs?|kickbacks?", re.I)
nl=ns=nr=0; vols=collections.Counter(); refs=[]
for v,d,dt,txt in rows:
    txt=re.sub(r"\s+"," ",txt); a=bool(L.search(txt)); b=bool(STRICT.search(txt)); c=bool(REF.search(txt))
    nl+=a and b; nr+=a and c
    if a and c: vols[v]+=1; refs.append("%s/%s %s"%(v,d,dt))
print("N=%d; literal Lockheed + one of the words: %d of %d; referent (Lockheed + bribe/scandal/corrupt/payoff wording): %d of %d" % (len(rows), nl, len(rows), nr, len(rows)))
print("referent volumes:", vols.most_common()); print("referent docs:", refs)
