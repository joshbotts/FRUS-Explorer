"""The UI-test Meaning seam's figures over a pool: Hamming-800 candidates of a sign vector."""
import json, sys
import numpy as np
pool = sys.argv[1]
F = np.load(f"{pool}/doc_f32_768.npy", mmap_mode="r")
keys = [json.loads(l) for l in open(f"{pool}/doc_keys.jsonl")]
bits = np.packbits(np.asarray(F[:, :512]) >= 0, axis=1)  # MSB-first, zero packs as 1
row = {(k["v"], k["d"]): i for i, k in enumerate(keys)}
pop = np.array([bin(i).count("1") for i in range(256)], dtype=np.uint16)
def ham(qrow):
    x = np.bitwise_xor(bits, bits[qrow])
    return pop[x].sum(axis=1)
def cand(qrow, k=800):
    h = ham(qrow)
    order = np.lexsort((np.arange(len(h)), h))[:k]
    return order, h
fix = "frus1961-63v06"
fixrows = [i for i, k in enumerate(keys) if k["v"] == fix]
print("fixture rows", len(fixrows), fixrows[:3])
def pct(h, off):
    c = 1 - 2 * h / 512
    return round(max(0, min(1, (c - off) / (1 - off))) * 100), c
for label, q in (("near d2", row[(fix, "d2")]), ("far frus1861/d1", row[("frus1861", "d1")])):
    order, h = cand(q)
    top = [(keys[i]["v"], keys[i]["d"], int(h[i])) for i in order[:6]]
    print(label, "first six:", top)
    inside = [i for i in order if keys[i]["v"] == fix]
    vols = {keys[i]["v"] for i in order if keys[i]["v"] != fix}
    print(f"  fixture rows among 800: {len(inside)}; unscored {800 - len(inside)} in {len(vols)} volumes")
    for d in ("d1", "d2", "d3"):
        r = row[(fix, d)]
        rank = int(np.where(np.lexsort((np.arange(len(h)), h)) == r)[0][0]) + 1
        print(f"  {d}: h={int(h[r])} rank={rank} shown raw={pct(h[r],0)[0]}% calibrated={pct(h[r],0.47)[0]}% cos={pct(h[r],0)[1]:.4f}")
