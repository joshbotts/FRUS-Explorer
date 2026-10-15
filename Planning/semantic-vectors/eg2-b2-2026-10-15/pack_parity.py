import json, os, sys, numpy as np
sys.path.insert(0, "tools/semantic-harvest/corpus-gates")
from pool_docs import truncate, int8_quantize, pack_bits
pool, packdir, D = sys.argv[1], sys.argv[2], int(sys.argv[3])
idx = json.load(open(os.path.join(packdir, "out/semantic-vectors-index.json")))
keys = [json.loads(l) for l in open(os.path.join(pool, "doc_keys.jsonl"))]
row_of = {}
for i, k in enumerate(keys): row_of.setdefault(k["v"], []).append(i)
order = []
for v in idx["volumes"]:
    vid = v["v"]; assert v["r"] == len(order)
    order += row_of[vid]
assert len(order) == len(keys) == idx["documentCount"]
F = np.load(os.path.join(pool, "doc_f32_768.npy"))
cut = truncate(F[order], D).astype(np.float32)
bits = pack_bits(cut)
binary = np.fromfile(os.path.join(packdir, "out/semantic-vectors-binary.bin"), dtype=np.uint8)
print("index keys", list(idx.keys()), "volume keys", list(idx["volumes"][0].keys()))
print("provenanceDigest", idx["provenanceDigest"], "retrieval", idx["retrieval"])
# find sign-bit block: try offset 0 and search header
rowbytes = D // 8
n = len(order)
for off in range(0, 256, 4):
    blk = binary[off:off + n * rowbytes].reshape(n, rowbytes)
    eq = (blk == bits).all(axis=1).mean()
    if eq > 0.99:
        print("sign bits match at offset", off, "rows equal", (blk == bits).all(axis=1).sum(), "of", n)
        break
else:
    print("no offset matched")
