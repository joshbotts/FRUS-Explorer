import sqlite3, json
from docs_list import SECTIONS
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
S=sorted({a.split("/")[0] for s,l in SECTIONS for a in l})
db.execute("CREATE TEMP TABLE sv(volume_id TEXT)"); db.executemany("INSERT INTO sv VALUES(?)",[(v,) for v in S])
NF="c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
def n(expr, insv=None):
    where = "" if insv is None else (" AND c.volume_id IN (SELECT volume_id FROM sv)" if insv else " AND c.volume_id NOT IN (SELECT volume_id FROM sv)")
    return db.execute(f"SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND {NF}{where}",(expr,)).fetchone()[0]
def den(insv):
    where = " AND c.volume_id IN (SELECT volume_id FROM sv)" if insv else " AND c.volume_id NOT IN (SELECT volume_id FROM sv)"
    return db.execute(f"SELECT COUNT(*) FROM document_cache c WHERE {NF}{where}").fetchone()[0]
dS,dN=den(True),den(False)
print(f"FALSE-FRIEND TEST. on-topic scope S = {len(S)} volumes ({dS} non-apparatus docs, Ed2 suppressed); rest = {dN} docs")
for name,e in [("corrupt (term supplied by the question)","body_text:corrupt"),("core family",'body_text:(corrupt OR brib* OR graft OR embezzl OR kickback OR "questionable payments" OR "illicit payments")'),("CONTROL phrase 'Department of State'",'body_text:"Department of State"'),("CONTROL term 'Ambassador'",'body_text:Ambassador'),("NEGATIVE control zzzimpossiblezzz",'body_text:zzzimpossiblezzz')]:
    a,b=n(e,True),n(e,False)
    print(f"{name:45s} S: {a} of {dS} ({1000*a/dS:.1f}/1000)   rest: {b} of {dN} ({1000*b/dN:.1f}/1000)")
print("\nSQL for each row: SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH <expr> AND is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN (Ed2 volumes) AND volume_id [NOT] IN (scope S)")
# per-volume positive control: Department of State in every volume?
r=db.execute("""SELECT volume_id FROM document_cache GROUP BY volume_id EXCEPT SELECT DISTINCT c.volume_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'body_text:"Department of State"'""").fetchall()
print("\nvolumes with zero 'Department of State' hits (positive control failures):",r)
# coverage by decade after 1988 and before 1860
print("\nCOVERAGE: dated non-apparatus docs by decade, <1860 and >=1980")
for r in db.execute(f"SELECT substr(d.date_iso,1,3)||'0s',COUNT(*),COUNT(DISTINCT c.volume_id) FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE {NF} AND (d.date_iso<'1860' OR d.date_iso>='1980') GROUP BY 1 ORDER BY 1"): print(r)
print("\nCOUNTERPART/PERIOD VOCABULARY, doc counts by era (non-apparatus): <1900 | 1900-1945 | >1945")
eras=[("<1900","d.date_iso<'1900'"),("1900-45","d.date_iso>='1900' AND d.date_iso<'1946'"),(">1945","d.date_iso>='1946'")]
terms=['corrupt','brib*','graft','peculat','defalcat*','malversat*','jobber*','extort*','squeez*','"official misconduct"','malfeasance','"improper payments"','"illegal payments"','"secret commissions"']
den_e=[db.execute(f"SELECT COUNT(*) FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE {NF} AND {w}").fetchone()[0] for _,w in eras]
print("denominators",dict(zip([e for e,_ in eras],den_e)))
for t in terms:
    row=[]
    for (e,w),dd in zip(eras,den_e):
        c=db.execute(f"SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE frus_documents MATCH ? AND {NF} AND {w}",('body_text:'+t,)).fetchone()[0]
        row.append(f"{c} of {dd} ({1000*c/dd:.1f}/1000)")
    print(f"{t:26s}", " | ".join(row))
