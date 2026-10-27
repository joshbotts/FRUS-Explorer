# Shared loader for the semantic vector artifacts (Appendix A §A.3-A.4). Identity ONLY from the index's id segments.
import json, struct
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
SH = "/Users/jbotts/frus-analysis/c3/SemanticVectors/"
IDX = json.load(open(R + "semantic-vectors-index.json"))
def numeric_part(doc_id):
    if not doc_id.startswith("d"): return None
    digits = doc_id[1:]
    if not digits or not digits.isdigit(): return None
    if len(digits) > 1 and digits[0] == "0": return None
    return int(digits)
def decode_segments(segments):
    ids = []
    for seg in segments:
        assert seg["s"] == len(ids)
        ids.append(seg["i"])
        if seg["n"] > 1:
            base = numeric_part(seg["i"]); ids.extend(f"d{base + k}" for k in range(1, seg["n"]))
    return ids
row_of, doc_of, vol_rows = {}, [], {}
for vi, vol in enumerate(IDX["volumes"]):
    ids = decode_segments(vol["seg"]); assert len(ids) == vol["n"], vol["v"]
    vol_rows[vol["v"]] = (vol["r"], vol["n"], vi)
    for k, d in enumerate(ids):
        row_of[(vol["v"], d)] = vol["r"] + k; doc_of.append((vol["v"], d))
BLOB = open(R + "semantic-vectors-binary.bin", "rb").read()
assert BLOB[:4] == b"FRSV"
VER, DIMS, DOCS, CENTS = struct.unpack("<IIII", BLOB[4:20]); BPR = DIMS // 8
DIGEST = BLOB[20:52].hex()
SIGNS = [int.from_bytes(BLOB[64 + r * BPR: 64 + (r + 1) * BPR], "big") for r in range(DOCS)]
def ham(a, b): return bin(SIGNS[a] ^ SIGNS[b]).count("1")
def centroid(i):
    o = 64 + DOCS * BPR + i * (DIMS + 4)
    codes = struct.unpack(f"<{DIMS}b", BLOB[o:o + DIMS]); sc = struct.unpack("<f", BLOB[o + DIMS:o + DIMS + 4])[0]
    return [c * sc for c in codes]
MAP = open(R + "semantic-map.bin", "rb").read(); assert MAP[:4] == b"FRSM"
MAP_DIGEST = MAP[20:52].hex()
def placement(r):
    return struct.unpack("<hhH", MAP[64 + 6 * r: 64 + 6 * r + 6])
def shard(v):
    b = open(SH + v + ".vec", "rb").read(); assert b[:4] == b"FRSS"
    dims, n = struct.unpack("<II", b[8:16]); dg = b[16:48].hex()
    codes = b[64:64 + n * dims]; scales = struct.unpack(f"<{n}f", b[64 + n * dims: 64 + n * dims + 4 * n])
    return dg, dims, n, codes, scales
