import sqlite3,collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
exec(open("pd_headers.py").read().split("for v in PD:")[0].replace("import sqlite3,re","import re").replace('db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)',''))
setA=[]
for v in PD:
    setA+= [(r[0],r[1]) for r in db.execute("""SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id=? AND d.is_front_matter=0 AND d.is_editorial_note=0""",(Q,v))]
print("SET A (PD/info volumes, header names an East Asia/Pacific place or office):",len(setA),"docs")
vols=[l.strip() for l in open("scope_vols.txt")]
PDV=PD
REG=[v for v in vols if v not in PDV]
FAM='(USIA OR USIS OR "Voice of America" OR "information program" OR "psychological warfare" OR "psychological strategy" OR "United States Information")'
ph=",".join("?"*len(REG))
setB=[(r[0],r[1]) for r in db.execute("SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN (%s) AND d.is_front_matter=0 AND d.is_editorial_note=0"%ph,[FAM]+REG)]
print("SET B (regional volumes, family A):",len(setB),"docs")
def came(S,label):
    c=collections.Counter(); n=0
    for v,d in S:
        r=db.execute("select record_group,series_name,repository from document_sources where volume_id=? and document_id=?",(v,d)).fetchone()
        if r: n+=1; c[(r[2],r[0],r[1])]+=1
    print("\nCAME-FROM channel,",label,": documents with a document_sources row:",n,"of",len(S))
    for k,x in c.most_common(12): print("  ",x,k)
def pointed(S,label):
    c=collections.Counter(); docs=set(); rows=0
    for v,d in S:
        for r in db.execute("select repository,collection,anchor from external_citations where volume_id=? and document_id=?",(v,d)):
            c[(r[0],r[1],r[2])]+=1; docs.add((v,d)); rows+=1
    print("\nPOINTED-AT channel,",label,": documents with >=1 external_citations row:",len(docs),"of",len(S),"; rows",rows)
    for k,x in c.most_common(12): print("  ",x,k)
came(setA,"Set A"); pointed(setA,"Set A"); came(setB,"Set B"); pointed(setB,"Set B")
