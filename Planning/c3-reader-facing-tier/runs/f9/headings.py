import sqlite3,json,re
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
out=open('headings_all.txt','w'); hits=open('headings_hits.txt','w')
pat=re.compile(r'(informat|propagand|psycholog|cultur|USIA|image|public diplomacy|exchange|broadcast|radio|opinion|attitude|ideolog|educat)',re.I)
asia=re.compile(r'(Asia|Far East|China|Chinese|Japan|Korea|Vietnam|Indochina|Laos|Cambodia|Philippin|Indonesia|Burma|Thai|Pacific|Taiwan|Formosa|Malay|Singapore|Australia|New Zealand)',re.I)
def walk(vid,secs,depth,chain):
    for s in secs:
        t=re.sub(r'\s+',' ',s.get('title') or '')
        n=len(s.get('documentIds') or [])
        ids=s.get('documentIds') or []
        line=f"{vid}\t{depth}\t{s.get('sectionId')}\t{n}\t{(ids[0]+'-'+ids[-1]) if ids else ''}\t{t}"
        out.write(line+'\n')
        ch=chain+' > '+t
        if pat.search(t) and (asia.search(ch) or 'PubDip' in vid or vid in ('frus1955-57v09','frus1961-63v25','frus1969-76v38p2','frus1977-80v30')):
            hits.write(line+'\n')
        walk(vid,s.get('subsections') or [],depth+1,ch)
for vid,js in c.execute("select volume_id,structure_json from volume_structures"):
    j=json.loads(js); walk(vid,j.get('sections',[]),0,vid)
