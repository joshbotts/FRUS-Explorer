import sqlite3,glob,re
exec(open("arch.py").read().split("def came")[0])
n306=0; rgc={}
for v,d in setA:
    r=db.execute("select record_group,repository from document_sources where volume_id=? and document_id=?",(v,d)).fetchone()
    rgc[r[0]]=rgc.get(r[0],0)+1
print("Set A record_group counts (document_sources.record_group):",rgc)
PDV=PD
tot=db.execute("select count(*) from document_cache where volume_id in (%s) and is_front_matter=0 and is_editorial_note=0"%",".join("?"*len(PDV)),PDV).fetchone()[0]
print("non-apparatus docs in the 7 information/public-diplomacy volumes:",tot)
# repository for Set A
rep={}
for v,d in setA:
    r=db.execute("select repository from document_sources where volume_id=? and document_id=?",(v,d)).fetchone(); rep[r[0]]=rep.get(r[0],0)+1
print("Set A repository counts:",rep)
fs=glob.glob("docs/*.txt"); print("dumped files:",len(fs))
ok=0
for f in fs:
    v,d=re.match(r"docs/(.+?)__(.+)\.txt",f).groups()
    L=db.execute("select length(body_text) from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()[0]
    body=open(f).read().split("\nBODY:\n",1)[1]
    if len(body)==L: ok+=1
print("dumped whole (captured length = length(body_text)):",ok,"of",len(fs))
