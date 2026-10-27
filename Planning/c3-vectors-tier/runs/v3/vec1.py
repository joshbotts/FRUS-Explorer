from vec import *
import json
print("index digest",idx["provenanceDigest"])
print("binary digest",bin_digest, "ver/dims/docs/cents",ver,dims,docs,cents)
print("map digest",map_blob[20:52].hex(), "map docs/clusters", struct.unpack("<II",map_blob[8:16]))
gens=set(open("/Users/jbotts/frus-analysis/c3/SemanticVectors/.generation").read().split())
print("shard .generation",gens)
# shard header digests
bad=0
for f in os.listdir("/Users/jbotts/frus-analysis/c3/SemanticVectors"):
    if f.endswith(".vec"):
        h=open("/Users/jbotts/frus-analysis/c3/SemanticVectors/"+f,"rb").read(64)
        if h[16:48].hex()!=idx["provenanceDigest"]: bad+=1
print("shards with mismatched digest:",bad)
print("round trip volumes decoded:",ok,"of",len(idx["volumes"]), "rows mapped", len(row_of))
