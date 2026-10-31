import json,struct,random
import numpy as np
R="/Applications/FRUS Explorer.app/Contents/Resources/"
blob=open(R+"semantic-vectors-binary.bin","rb").read()
ver,dims,docs,cents=struct.unpack("<IIII",blob[4:20]); bpr=dims//8
signs=np.frombuffer(blob,dtype=np.uint8,count=docs*bpr,offset=64).reshape(docs,bpr)
POP=np.array([bin(i).count("1") for i in range(256)],dtype=np.uint8)
rng=random.Random(1877); pr=[(rng.randrange(docs),rng.randrange(docs)) for _ in range(20000)]  # advance the generator as vec.py did
samp=[rng.randrange(docs) for _ in range(200)]
k1=[];k10=[];k25=[]
for r in samp:
    h=np.sort(POP[np.bitwise_xor(signs,signs[r])].sum(axis=1,dtype=np.int32)); k1.append(h[1]); k10.append(h[10]); k25.append(h[25])
print("200-sample (same seed sequence): 1st-nbr median %d; 10th-nbr median %d q1 %d q3 %d; 25th median %d"%(np.median(k1),np.median(k10),np.percentile(k10,25),np.percentile(k10,75),np.median(k25)))
print("memo: 1st 84; 10th 101 (93, 109); 25th 107")
