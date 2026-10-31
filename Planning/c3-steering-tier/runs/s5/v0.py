from vecsetup import *
gen=open(SH+".generation").read().strip()
print("index digest ",ix["provenanceDigest"]); print("binary digest",bdigest); print("map digest   ",mdigest); print(".generation  ",gen)
print("binary hdr: version",ver,"dims",dims,"docs",docs,"centroids",cents)
print("map hdr:", struct.unpack("<IIII",mp[4:20]))
print("round trip: volumes",len(vol_rows),"all lengths match n; rows covered",sum(1 for d in doc_of if d is not None),"of",docs)
sc=ix["retrieval"]["scoreCalibration"]; print("scoreCalibration",json.dumps(sc)); print("measuredRecallAt10",ix["retrieval"]["measuredRecallAt10"], "generated",ix["generated"],"harvestGenerated",ix["harvestGenerated"])
print("volumes in index order sample:", [v["v"] for v in ix["volumes"][:3]], "subseries count", len(ix["subseries"]))
print("is frus1951-54IranEd2 in index:", "frus1951-54IranEd2" in vol_rows)
