import json, struct, sqlite3, re, difflib
import numpy as np
RES="/Applications/FRUS Explorer.app/Contents/Resources"; DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
idx=json.load(open(RES+"/semantic-vectors-index.json")); blob=open(RES+"/semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20])
row_of={}; doc_of={}
for v in idx["volumes"]:
    ids=[]
    for seg in v["seg"]:
        ids.append(seg["i"])
        if seg["n"]>1: base=int(seg["i"][1:]); ids+=["d%d"%(base+k) for k in range(1,seg["n"])]
    for k,d in enumerate(ids): row_of[(v["v"],d)]=v["r"]+k; doc_of[v["r"]+k]=(v["v"],d)
bits=np.frombuffer(blob,dtype=np.uint8,count=docs*64,offset=64).reshape(docs,64)
popc=np.array([bin(i).count("1") for i in range(256)],dtype=np.uint8)
con=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
hits=con.execute("""SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
 WHERE frus_documents MATCH 'corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')""").fetchall()
rows=sorted(row_of[k] for k in hits if k in row_of)
print("hit set",len(hits),"with a vector row",len(rows))
sub=bits[rows]; pairs=[]
for i in range(len(rows)-1):
    d=popc[np.bitwise_xor(sub[i+1:],sub[i])].sum(axis=1)
    for j in np.nonzero(d<49.0)[0]: pairs.append((int(d[j]),doc_of[rows[i]],doc_of[rows[i+1+j]]))
pairs.sort(); print("pairs under 49.0:",len(pairs))
agree=[]; 
for h,a,b in pairs:
    ta=re.sub(r"\s+"," ",con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",a).fetchone()[0])
    tb=re.sub(r"\s+"," ",con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",b).fetchone()[0])
    r=difflib.SequenceMatcher(None,ta[:6000],tb[:6000],autojunk=False).ratio()
    if r>=0.90: agree.append((a,b,round(r,3)))
print("pairs whose texts agree (ratio>=0.90):",len(agree))
par={}
def f(x):
    while par.get(x,x)!=x: x=par[x]
    return x
for a,b,_ in agree: par[f(a)]=f(b)
comps={}
for a,b,_ in agree:
    comps.setdefault(f(a),set()).update([a,b])
print("components",len(comps),"redundant copies",sum(len(c)-1 for c in comps.values()))
