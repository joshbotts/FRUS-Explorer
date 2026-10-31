from h import *
c=conn()
terms=['"psychological warfare"','"psychological operations"','"psychological strategy"','"information program"','USIS','USIA','"United States Information Service"','"Voice of America"','"cultural exchange"','"educational exchange"','Fulbright','"Asia Foundation"','propaganda','prestige','"image of the United States"','"American image"','"hearts and minds"','"cultural program"','"leader grant"','"exchange of persons"','"binational center"','"Radio Free Asia"','anti-American','neutralism','"soft power"','"public diplomacy"','"information officer"','"cultural affairs"','"Asian mentality"','"oriental mind"','"face"','"Department of State"','ZZZ_IMPOSSIBLE_ZZZ','"public opinion"','"Information Agency"','"Information Service"','"psychological"','"Operations Coordinating Board"','"Psychological Strategy Board"']
SQLT="SELECT COUNT(*), COUNT(DISTINCT f.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND f.frus_documents MATCH ?"
print(SQLT)
for t in terms:
    q="body_text:"+t if not t.startswith('"') and False else t
    try:
        r=c.execute(SQLT,(t,)).fetchone()
    except Exception as e:
        r=str(e)
    print(t,r,flush=True)
