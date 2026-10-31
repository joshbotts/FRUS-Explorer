import sys,sqlite3,re
sys.path.insert(0,'.')
from vec import *
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
eap=set(open('eap_volumes.txt').read().split())
QA='(USIA OR USIS OR "Information Agency" OR "Information Service" OR "Voice of America" OR "information program" OR "psychological program" OR "psychological strategy" OR "cultural exchange" OR "educational exchange")'
anchors=[tuple(a.split('/')) for a in sys.argv[1:]]
out=open('vec_neighbours.txt','a')
for a in anchors:
    top,hamtop=neighbours(a,15)
    print(f"ANCHOR {a[0]}/{a[1]}"); out.write(f"ANCHOR {a[0]}/{a[1]}\n")
    for cs,h,(v,i) in top:
        cal=(cs-0.40)/0.60
        r=con.execute("SELECT substr(replace(header,char(10),' '),1,100),is_front_matter,is_editorial_note,(SELECT date_iso FROM document_dates dd WHERE dd.volume_id=d.volume_id AND dd.document_id=d.document_id) FROM document_cache d WHERE volume_id=? AND document_id=?",(v,i)).fetchone()
        inqa=con.execute("SELECT 1 FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id=? AND d.document_id=?",(QA,v,i)).fetchone() is not None
        line=f"  ham {h:3d} cos_raw {cs:.3f} calibrated {cal*100:.0f}%  {v}/{i} {'EAPvol' if v in eap else 'other'} inQAfts={inqa} {r[3]} {r[0] if r else '(not in db)'}"
        print(line); out.write(line+"\n")
