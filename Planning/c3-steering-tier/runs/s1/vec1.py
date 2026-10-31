from vec_setup import *
print("version",ver,"dims",dims,"docs",docs,"centroids",cents)
for k,v in digests.items(): print(k,v)
print("ALL AGREE:",len(set(digests.values()))==1, "generated stamp:",idx["generated"], "harvestGenerated:",idx["harvestGenerated"])
print("model:",idx["provenance"]["model"],"retrieval:",{k:idx["retrieval"][k] for k in ("measuredRecallAt10","rerankPool","scoreCalibration")})
print("round trip: volumes",len(idx["volumes"]),"sum n",sum(v["n"] for v in idx["volumes"]),"= docs",docs,"rows mapped",len(row_of))
shards=glob.glob(SH+"/*.vec"); print("shards",len(shards))
bad=[]
for f in shards:
    h=open(f,"rb").read(48)
    if h[:4]!=b"FRSS" or h[16:48].hex()!=digests["index"]: bad.append(f)
print("shard digest mismatches:",len(bad))
rng=random.Random(1877)
pairs=[int(np.bitwise_count(bits[rng.randrange(docs)]^bits[rng.randrange(docs)]).sum()) for _ in range(20000)]
mean,sd=statistics.mean(pairs),statistics.pstdev(pairs)
first=sorted(pairs)[len(pairs)//100]
print("random pairs n=20000 mean %.2f sd %.2f p1 %d min %d; mean-8sd = %.2f"%(mean,sd,first,min(pairs),mean-8*sd))
kth=sorted(int(np.sort(distances(r))[24]) for r in random.Random(1878).sample(range(docs),200))
nn1=sorted(int(np.sort(distances(r))[0]) for r in random.Random(1878).sample(range(docs),200))
print("25th-neighbour distance over 200 random docs: min %d median %d p90 %d max %d"%(kth[0],kth[100],kth[180],kth[-1]))
print("1st-neighbour distance over same 200: min %d median %d p90 %d max %d"%(nn1[0],nn1[100],nn1[180],nn1[-1]))
