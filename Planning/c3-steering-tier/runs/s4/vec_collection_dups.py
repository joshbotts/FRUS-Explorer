from vec import *
import json
docs=[tuple(x) for x in json.load(open("work/collection_docs.json"))]
print("collection documents:",len(docs),"in vector index:",sum(1 for k in docs if k in row_of))
nd=near_duplicates(set(docs))
print("pairs closer than mean-8sd line (%.2f) within the collection:"%line,len(nd))
pk=pickle=__import__("pickle").load(open("work/neardups.pkl","rb"))
cs=set(docs)
hit=[x for x in pk if (x[1] in cs or x[2] in cs)]
print("pairs in the 3,165-document scope check that involve a collection document:",len(hit))
for h,a,b in hit: print(h,a,b)
# also nearest-neighbour distance of each collection member within the collection (requirement: each member's NN distance in the set)
rows=[row_of[k] for k in docs]
print("each member's nearest-neighbour distance within the collection set:")
out=[]
for k in docs:
    r=row_of[k]; d=np.bitwise_count(bits[rows]^bits[r]).sum(axis=1).astype(int)
    d[rows.index(r)]=1<<20
    j=int(np.argmin(d)); out.append((int(d[j]),k,docs[j]))
out.sort()
print("min %d, median %d, max %d; members with NN below the line: %d"%(out[0][0],out[len(out)//2][0],out[-1][0],sum(1 for o in out if o[0]<line)))
for o in out[:5]: print(" closest pairs:",o)
