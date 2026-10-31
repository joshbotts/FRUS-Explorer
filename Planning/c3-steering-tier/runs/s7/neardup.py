import numpy as np,pickle
S=np.load("signs.npy"); row_of,doc_of=pickle.load(open("idmap.pkl","rb"))
for p in "frus1875v01/d199 frus1875v02/d393 frus1947v07/d582 frus1948v07/d43 frus1961-63v22/d202 frus1961-63v22/d204 frus1964-68v04/d215 frus1964-68v05/d258 frus1969-76ve12/d218 frus1969-76ve15p2/d292 frus1977-80v03/d152".split():
    v,d=p.split("/"); r=row_of[(v,d)]; dd=np.bitwise_count(S^S[r]).sum(1); dd[r]=9999; m=int(dd.argmin())
    print(p,"min hamming",int(dd[m]),"to",doc_of[m])
