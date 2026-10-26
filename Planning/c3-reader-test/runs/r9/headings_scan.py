# headings_scan.py: walk volume_structures.structure_json and print every section whose title matches /recogni/i,
# with the count of documentIds under it (own + descendants). Also prints positive/negative controls.
import sqlite3,json,re,sys
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
pat=re.compile(sys.argv[1],re.I)
out=open(sys.argv[2],'w')
nvol=0; nhit=0
def walk(v,sec,path):
    global nhit
    t=re.sub(r'\s+',' ',sec.get('title','')).strip()
    ids=list(sec.get('documentIds',[]))
    def alldocs(s):
        r=list(s.get('documentIds',[]))
        for c in s.get('subsections',[]): r+=alldocs(c)
        return r
    if pat.search(t):
        nhit+=1
        d=alldocs(sec)
        out.write('\t'.join([v,str(len(d)),(d[0]+'..'+d[-1]) if d else '-',' > '.join(path+[t])])+'\n')
    for c in sec.get('subsections',[]): walk(v,c,path+[t])
for v,j in con.execute("SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id"):
    nvol+=1
    for s in json.loads(j).get('sections',[]): walk(v,s,[])
out.close()
print('volumes walked',nvol,'heading hits',nhit)
