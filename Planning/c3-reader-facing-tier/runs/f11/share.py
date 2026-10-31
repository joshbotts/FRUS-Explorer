import sqlite3,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open("scope_vols.txt")]
PDV=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30','frus1955-57v09','frus1961-63v25']
REG=[v for v in vols if v not in PDV]
ph=",".join("?"*len(REG))
SQL="SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN (REG) AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.volume_id,d.document_id"
SEP=r"[\s\-,.()]*"
def tol(words):  # each word with inflections, any run of space/hyphen/comma/paren/full stop between
    parts=[re.escape(w)+r"\w{0,4}" for w in words]
    return re.compile(r"\b"+(r"[\s\-,.()]+").join(parts),re.I)
def strict(words): return re.compile(r"\b"+r"\s".join(re.escape(w) for w in words)+r"\b",re.I)
fams=[("information program",'"information program"',["information","program"]),
      ("psychological warfare",'"psychological warfare"',["psychological","warfare"]),
      ("psychological strategy",'"psychological strategy"',["psychological","strategy"]),
      ("United States Information",'"United States Information"',["United","States","Information"])]
for name,m,words in fams:
    hits=db.execute(SQL.replace("(REG)","(%s)"%ph),[m]+REG).fetchall()
    n=len(hits); k=40 if n>=40 else n
    idx=[int(i*n/k) for i in range(k)] if n>=300 or True else range(n)
    samp=[hits[i] for i in idx]
    if n<300:  # whole set under 300 -> check the whole set
        samp=hits
    s_ok=t_ok=0
    for v,d in samp:
        r=db.execute("select header||' '||coalesce(dateline,'')||' '||coalesce(source_note,'')||' '||body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
        txt=re.sub(r"\s+"," ",r[0])
        if strict(words).search(txt): s_ok+=1
        if tol(words).search(txt): t_ok+=1
    print("PHRASE %-26s FTS MATCH %-30s hits in REG: %d ; checked %d (%s) ; STRICT %d of %d ; TOLERANT %d of %d"%(name,m,n,len(samp),"whole set" if n<300 else "40 evenly spaced",s_ok,len(samp),t_ok,len(samp)))
