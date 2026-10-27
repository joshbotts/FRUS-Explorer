# Refuter: own decode of the bundle's index (run-length id segments), own Hamming scan over the binary's sign rows,
# re-run of the session's neighbour lists, the V5 pairs, and the map's cluster shares (N07).
import json, struct, re, sqlite3, collections, time
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ix=json.load(open(R+"semantic-vectors-index.json"))
# A.3 decode: a segment {i: first id, n: count, s: start offset}; ids after the first are d<base+k> for a plain d<number> id
def decode(volume):
    ids=[]
    for seg in volume["seg"]:
        assert seg["s"]==len(ids), (volume["v"],seg)
        first=seg["i"]; ids.append(first)
        if seg["n"]>1:
            m=re.fullmatch(r"d([1-9][0-9]*)",first); assert m, (volume["v"],seg)
            base=int(m.group(1)); ids.extend("d%d"%(base+k) for k in range(1,seg["n"]))
    assert len(ids)==volume["n"], (volume["v"],len(ids),volume["n"])
    return ids
row_of={}; doc_of={}
for vol in ix["volumes"]:
    for k,i in enumerate(decode(vol)):
        row_of[(vol["v"],i)]=vol["r"]+k; doc_of[vol["r"]+k]=(vol["v"],i)
print("decoded rows:",len(row_of),"documentCount:",ix["documentCount"],"max row+1:",max(doc_of)+1)
print("frus1898/ch83 has a vector row:",("frus1898","ch83") in row_of)
b=open(R+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",b[4:20]); bpr=dims//8
S=[int.from_bytes(b[64+r*bpr:64+(r+1)*bpr],"big") for r in range(docs)]
def nn(anchor,k=10):
    q=S[anchor]
    ds=sorted((bin(q^S[r]).count("1"),r) for r in range(docs) if r!=anchor)[:k]
    return ds
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c=sqlite3.connect(DB,uri=True)
def info(v,d):
    return c.execute("SELECT dd.date_iso, substr(replace(d.header,char(10),' '),1,50), d.rowid IN (SELECT rowid FROM frus_documents WHERE frus_documents MATCH 'cuba OR cuban') FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.volume_id=? AND d.document_id=?",(v,d)).fetchone()
memo={("frus1874","d552"):[("frus1898/d490",61),("frus1898/d503",68),("frus1898/d531",71),("frus1898/d495",73),("frus1898/d526",77),("frus1902/d313",77),("frus1898/d544",78),("frus1898/d492",80),("frus1898/d498",80),("frus1897/d581",81)],
      ("frus1950v02","d440"):[("frus1948v09/d420",62),("frus1969-76ve10/d205",64),("frus1964-68v32/d300",69),("frus1969-76ve11p1/d278",69),("frus1946v11/d658",73),("frus1952-54v04/d351",73),("frus1958-60v06/d423",73),("frus1961-63v10-12mSupp/d729",74),("frus1958-60v06/d364",76),("frus1958-60v06/d527",77)]}
for a,expect in memo.items():
    t=time.time(); got=nn(row_of[a],10)
    mine=[("%s/%s"%doc_of[r],d) for d,r in got]
    print("ANCHOR %s/%s (row %d), %.1fs"%(a[0],a[1],row_of[a],time.time()-t))
    for (p,d) in mine:
        v,i=p.split("/"); print("   ham %3d %-28s %s"%(d,p,info(v,i)))
    print("   memo list:",expect)
    print("   SAME SET:",set(mine)==set(expect),"; SAME ORDER (ties aside):",[x[0] for x in mine]==[x[0] for x in expect],"; same distances:",sorted(d for _,d in mine)==sorted(d for _,d in expect))
# V5 pairs
def ham(a,b): return bin(S[row_of[a]]^S[row_of[b]]).count("1")
for a,bb in [(("frus1881","d405"),("frus1894app2","d394")),(("frus1961-63v06","d74"),("frus1961-63v11","d155")),(("frus1961-63v11","d18"),("frus1961-63v11","d21"))]:
    print("V5 pair",a,bb,"hamming",ham(a,bb))
# baseline spot check: random pairs seed 1877 (as the session) -> mean
import random,statistics
rnd=random.Random(1877); ds=[]
for _ in range(20000):
    x=rnd.randrange(docs); y=rnd.randrange(docs)
    if x!=y: ds.append(bin(S[x]^S[y]).count("1"))
print("V1 random pairs (seed 1877): n=%d mean=%.1f sd=%.1f min=%d"%(len(ds),statistics.mean(ds),statistics.pstdev(ds),min(ds)))
# map N07: cluster shares for the tier-1 Cuba set per band, and cluster 42's terms
m=open(R+"semantic-map.bin","rb").read()
mi=json.load(open(R+"semantic-map-index.json"))
print("map layout check: 64 + docs*6 =",64+docs*6,"size",len(m))
cl42=[x for x in mi["clusters"] if x["id"]==42][0]; print("cluster 42:",cl42["terms"],"documentCount",cl42["documentCount"])
def cluster(row): return struct.unpack("<hhH",m[64+row*6:64+row*6+6])[2]
ED2=('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
rows=c.execute("""SELECT d.volume_id,d.document_id,dd.date_iso FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
 WHERE frus_documents MATCH 'cuba OR cuban' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (?,?) AND dd.date_iso>='1870' AND dd.date_iso<'1990'""",ED2).fetchall()
for name,lo,hi in [("1870-1899","1870","1900"),("1900-1939","1900","1940"),("1940-1957","1940","1958"),("1958-1989","1958","1990")]:
    n=u=c42=miss=0
    for v,d,dt in rows:
        if lo<=dt<hi:
            r=row_of.get((v,d))
            if r is None: miss+=1; continue
            n+=1; k=cluster(r); u+=(k==0xFFFF); c42+=(k==42)
    print("N07 %s: Cuba docs with a row %d, unclustered %d, in cluster 42 %d, without a row %d"%(name,n,u,c42,miss))
# map placement of the overview's documents
for a in [("frus1874","d552"),("frus1898","d498"),("frus1902","d273"),("frus1941v07","d134"),("frus1948v09","d420"),("frus1950v02","d440"),("frus1958-60v06","d535"),("frus1961-63v11","d21"),("frus1969-76ve10","d205"),("frus1977-80v23","d18"),("frus1977-80v01","d129"),("frus1981-88v03","d10")]:
    k=cluster(row_of[a]); print("  map",a,"cluster","unclustered" if k==0xFFFF else k)
