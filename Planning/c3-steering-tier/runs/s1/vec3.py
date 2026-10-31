from vec_setup import *
import csv
from final_set import FINAL
con=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
mean=167.14; sd=14.77
# recompute baseline with the same seed to use exact numbers
rng=random.Random(1877)
pairs=[int(np.bitwise_count(bits[rng.randrange(docs)]^bits[rng.randrange(docs)]).sum()) for _ in range(20000)]
mean,sd=statistics.mean(pairs),statistics.pstdev(pairs); line=mean-8*sd
print("line",line)
def near_duplicates(scope):
    rows=sorted(row_of[k] for k in scope if k in row_of)
    arr=np.array(rows); found=[]
    for i,a in enumerate(rows[:-1]):
        d=np.bitwise_count(bits[arr[i+1:]]^bits[a]).sum(axis=1)
        for h,b in zip(d,arr[i+1:]):
            if h<line: found.append((int(h),doc_of[a],doc_of[int(b)]))
    return sorted(found)
scope=set()
for r in csv.DictReader(open("scan1.csv")):
    if r["volume_id"] not in ED2: scope.add((r["volume_id"],r["document_id"]))
print("lexical scope size",len(scope),"all in vector index:",all(k in row_of for k in scope))
nd=near_duplicates(scope)
print("LEXICAL SCOPE near-dup pairs:",len(nd))
for h,a,b in nd: print(h,a,b)
print("FINAL near-dup pairs:",near_duplicates(set(FINAL)))
# nearest-neighbour distance within final set
rowsF=[row_of[k] for k in FINAL]
for k in FINAL:
    r=row_of[k]; d=[int(np.bitwise_count(bits[r]^bits[x]).sum()) for x in rowsF if x!=r]
    print(k,"nearest within final set:",min(d))
