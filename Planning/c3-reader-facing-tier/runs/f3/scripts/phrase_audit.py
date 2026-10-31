# phrase_audit.py: FTS phrase count over scope (apparatus excluded) + literal share on an evenly spaced
# sample of 40 from the (volume_id,document_id)-sorted hit list (whole set if <300... census if <300).
# Literal test: Python re, IGNORECASE, over header+' '+dateline+' '+source_note+' '+body_text, whitespace-collapsed.
import sqlite3,re,sys,json
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con=sqlite3.connect(DB,uri=True)
vols=[l.strip() for l in open('/Users/jbotts/frus-analysis/c3f/runs/f3/scope_volumes.txt') if l.strip()]
vl=",".join("'%s'"%v for v in vols)
def run(label, match, words):
    sql=("SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid "
         "WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id IN (%s) "
         "ORDER BY c.volume_id,c.document_id"%vl)
    hits=con.execute(sql,(match,)).fetchall()
    n=len(hits)
    if n<300: samp=hits; mode="census"
    else:
        step=n/40.0; samp=[hits[int(i*step)] for i in range(40)]; mode="sample40"
    strict=re.compile(r'\b'+r' '.join(re.escape(w) for w in words)+r'\b',re.I)
    sep=r'[\s\-,().]+'
    tol=re.compile(r'\b'+sep.join(re.escape(w)+r'\w*' for w in words),re.I)
    s=t=0; misses=[]
    for v,d in samp:
        r=con.execute("SELECT header,coalesce(dateline,''),coalesce(source_note,''),body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        txt=re.sub(r'\s+',' ',' '.join(r))
        a=bool(strict.search(txt)); b=bool(tol.search(txt)); s+=a; t+=b
        if not b: misses.append(v+'/'+d)
    out=dict(label=label,match=match,sql=sql.replace(vl,'<scope_volumes.txt>'),hits=n,mode=mode,checked=len(samp),strict=s,tolerant=t,tolerant_misses=misses[:10])
    print(json.dumps(out)); sys.stdout.flush()
fam=json.load(open(sys.argv[1]))
for label,match,words in fam: run(label,match,words)
