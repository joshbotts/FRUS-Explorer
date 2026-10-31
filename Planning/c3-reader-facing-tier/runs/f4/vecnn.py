import json,sys,re,sqlite3
exec(open('vec.py').read().split("rng=random.Random(1877)")[0])
from h import conn
c=conn()
Q='''(USIS OR USIA OR JUSPAO OR "Information Agency" OR "Information Service" OR "psychological warfare" OR "psychological operations" OR "psychological strategy" OR "information program" OR "cultural exchange" OR "educational exchange" OR Fulbright OR "Voice of America" OR "exchange of persons" OR "hearts and minds" OR "cultural program" OR "Asia Foundation" OR "leader grant" OR "information officer" OR "cultural affairs" OR "cultural relations" OR "public diplomacy" OR "information activities")'''
c.execute("CREATE TEMP TABLE S2 AS SELECT d.volume_id v, d.document_id i FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ?",(Q,))
S2=set(c.execute("SELECT v,i FROM S2").fetchall())
Rv=set(S['R'] if False else json.load(open('scope_sets.json'))['R'])
anchors=[a.split('/') for a in sys.argv[1:]]
for v,i in anchors:
    r=row_of[(v,i)]
    d=dist_to(r); d[r]=9999
    order=np.argsort(d,kind='stable')[:40]
    print('\n## ANCHOR',v+'/'+i)
    n=0
    for o in order:
        vv,ii=doc_of[o]
        if vv.endswith('Ed2'): continue
        row=c.execute("SELECT is_front_matter,is_editorial_note,substr(replace(header,char(10),' '),1,95),dateline FROM document_cache WHERE volume_id=? AND document_id=?",(vv,ii)).fetchone()
        flag='NOT-IN-DB' if row is None else ('apparatus' if row[0] or row[1] else '')
        print('  ham',int(d[o]),vv+'/'+ii,'inR' if vv in Rv else '', 'FTShit' if (vv,ii) in S2 else 'noFTS', flag,'|',(row[2] if row else ''),'|',((row[3] or '')[:30] if row else ''))
        n+=1
        if n>=15: break
