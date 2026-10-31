import sqlite3,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
v77=[l.strip() for l in open("work/ea_vols_list.txt")]+['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08']
war=['frus1941v04','frus1942China','frus1942v01','frus1943China','frus1943v03','frus1944v05','frus1944v06','frus1945v06','frus1945v07']
def census(q,vols,strict,tol,label,extra=None):
    ph=",".join("?"*len(vols))
    rows=db.execute(f"select d.volume_id,d.document_id,d.header,d.dateline,d.source_note,d.body_text from frus_documents f join document_cache d on d.rowid=f.rowid where frus_documents match ? and d.volume_id in ({ph}) and d.is_front_matter=0 and d.is_editorial_note=0 order by 1,2",[q]+vols).fetchall()
    S=re.compile(strict,re.I);T=re.compile(tol,re.I)
    ns=nt=0
    for v,d,h,dl,sn,b in rows:
        t=" ".join((h+" "+dl+" "+sn+" "+b).split())
        ns+=bool(S.search(t));nt+=bool(T.search(t))
    print("%s: FTS hits %d; STRICT literal %d of %d; TOLERANT literal %d of %d (census of all hits, Python re, case-insensitive)"%(label,len(rows),ns,len(rows),nt,len(rows)))
census('"public opinion poll" OR "opinion survey"',v77,r"\b(public opinion poll|opinion survey)\b",r"\b(public[\W_]+opinion[\W_]+polls?|opinion[\W_]+surveys?|public[\W_]+opinion[\W_]+surveys?)\b","opinion-poll family, 77 volumes")
census('"office of war information"',war,r"\bOffice of War Information\b",r"\boffice[\W_]+of[\W_]+war[\W_]+information\b","Office of War Information, 9 wartime Far East volumes")
census('owi',war,r"\bOWI\b",r"\bO\.?W\.?I\.?\b","OWI acronym FTS hits, same 9 volumes")
