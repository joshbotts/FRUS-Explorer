# scan.py LO HI OUTCSV : for every non-apparatus FTS hit 'cuba OR cuban' dated [LO,HI), count Cuba mentions
# and Cuba-centred windows (+-250 chars) holding security-vocabulary and prosperity-vocabulary. Ed2 volumes excluded.
import sys,re,csv
from h import *
lo,hi,out=sys.argv[1:4]
SEC=re.compile(r"\b(secur\w*|strategic\w*|naval|coaling|defen[cs]\w*|menace\w*|annex\w*|cession|Monroe|European power\w*|Gulf of Mexico|Caribbean|Panama|isthmian|canal|missile\w*|Soviet\w*|communis\w*|Marxis\w*|subver\w*|guerrill\w*|military|troops|intervention|invasion|base|bases|filibuster\w*|insurrection|revolution\w*)\b",re.I)
PRO=re.compile(r"\b(sugar\w*|commerc\w*|trade|tariff\w*|reciproc\w*|duties|export\w*|import\w*|investment\w*|capital|market\w*|prosper\w*|embargo\w*|quota\w*|tobacco|property|properties|claims|economic\w*|exchange|loan\w*|customs)\b",re.I)
CUB=re.compile(r"\bCub(?:a|an|ans)\b")
c=con()
SQL="""SELECT d.volume_id,d.document_id,dd.date_iso,replace(substr(d.header,1,120),char(10),' '),d.body_text
FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE frus_documents MATCH 'cuba OR cuban' AND d.is_front_matter=0 AND d.is_editorial_note=0
AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND dd.date_iso>=? AND dd.date_iso<? ORDER BY dd.date_iso"""
w=csv.writer(open(out,"w",newline=""))
w.writerow("volume_id document_id date header len ncuba nsec npro nboth".split())
n=0
for v,d,dt,h,b in c.execute(SQL,(lo,hi)):
    pos=[m.start() for m in CUB.finditer(b)]
    ns=npr=nb=0
    for p in pos:
        win=b[max(0,p-250):p+250]
        s=bool(SEC.search(win)); q=bool(PRO.search(win))
        ns+=s; npr+=q; nb+=(s and q)
    w.writerow([v,d,dt,h,len(b),len(pos),ns,npr,nb]); n+=1
print(lo,hi,n)
