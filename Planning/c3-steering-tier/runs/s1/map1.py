from vec_setup import *
import collections
m=json.load(open(RES+"/semantic-map-index.json")); labels={c["id"]:c["terms"] for c in m["clusters"]}
mb=open(RES+"/semantic-map.bin","rb").read()
def cluster(row): return struct.unpack_from("<H",mb,64+6*row+4)[0]
FIN=[("frus1950v06","d832"),("frus1950v06","d841"),("frus1961-63v23","d356"),("frus1961-63v23","d358"),("frus1977-80v23","d252"),("frus1958-60v01","d111"),("frus1958-60v01","d135"),("frus1964-68v05","d197"),("frus1964-68v05","d258"),("frus1964-68v05","d395"),("frus1964-68v07","d91"),("frus1969-76v06","d175"),("frus1917-72PubDipv07","d177"),("frus1969-76ve09p2","d122"),("frus1969-76v27","d45"),("frus1969-76ve05p2","d119"),("frus1977-80v18","d206"),("frus1969-76ve11p1","d159"),("frus1969-76ve09p2","d161"),("frus1969-76ve12","d218"),("frus1969-76ve12","d219"),("frus1969-76ve12","d224"),("frus1969-76ve15p2","d292"),("frus1969-76v31","d149"),("frus1977-80v03","d248"),("frus1961-63v22","d244"),("frus1961-63v22","d249"),("frus1943China","d202"),("frus1944v06","d269")]
cs=[cluster(row_of[k]) for k in FIN]
print("map header documents:",struct.unpack("<I",mb[8:12])[0],"clusters:",struct.unpack("<I",mb[12:16])[0])
unc=sum(1 for c in cs if c==0xFFFF); print("unclustered:",unc,"of",len(cs))
cnt=collections.Counter(c for c in cs if c!=0xFFFF); print("distinct clusters:",len(cnt),"of",len(cs)-unc,"clustered docs; largest cluster holds",cnt.most_common(1))
for c,n in cnt.most_common(8): print(c,n,labels.get(c))
tot=struct.unpack("<I",mb[8:12])[0]
allc=np.frombuffer(mb,dtype="<u2",count=tot*3,offset=64).reshape(tot,3)[:,2]
print("corpus-wide unclustered:",int((allc==0xFFFF).sum()),"of",tot)
