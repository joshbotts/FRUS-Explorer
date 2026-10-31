### A.9 The vectors operating card

This is what a session's prompt carries of this appendix when the brief hands over the artifacts:
the formats and the code, about a third of the appendix's length. The rules are the §12 block's
SEMANTIC VECTORS section, and when to use them is [§14.17](#1417-the-second-finding-aid-when-the-vectors-enter-the-pass).
The rest of this appendix is the reference, read from the guide when a question needs it. The card
carries no figure, because every distance, share and baseline is one generation's: a session
computes the ones it relies on.

**The files.** `RES` is the bundle's `Resources/` folder and `DB` the index copy, as the brief
names them.
- `semantic-vectors-index.json`: identity, provenance and the retrieval block.
- `semantic-vectors-binary.bin`: Tier 1, one sign vector per document, then the volume and
  subseries centroids.
- `semantic-map.bin` and `semantic-map-index.json`: the 2-D layout and its clusters.
- `semantic-shards-manifest.json` and the shard folder's `<volume>.vec` files: Tier 2, int8
  vectors for reranking (§A.6).

**The one family rule** (§A.2). Every artifact carries the same 32-byte provenance digest:
- the index's `provenanceDigest`, in hex;
- bytes 20–51 of the corpus binary and of the map;
- bytes 16–47 of each shard;
- the shards manifest's `provenanceDigest`, and the shard folder's `.generation` file.

Compare every one you touch before any scoring, and on a mismatch stop and say so.

**The layouts** (§A.4). Each file is little-endian, with a 64-byte header. Read `dims` from the
header rather than assuming it.

```
semantic-vectors-binary.bin  0 "FRSV" | 4 version | 8 dims | 12 documents | 16 centroids | 20 digest
                             64: sign bits, documents x dims/8 B, MSB-first, a set bit when >= 0;
                             then centroids x (dims + 4) B: int8 codes, then a Float32 scale
<volume>.vec                 0 "FRSS" | 4 version | 8 dims | 12 documents | 16 digest
                             64: int8 codes, documents x dims B; then Float32 scales, documents x 4 B
semantic-map.bin             0 "FRSM" | 4 version | 8 documents | 12 clusters | 16 grid | 20 digest
                             64: documents x 6 B (int16 x, int16 y, uint16 cluster; 0xFFFF unclustered)
```

**Identity is stored, never derived** (§A.3). An id guessed from a row's ordinal mis-keys every
document behind a letter-suffixed id, and nothing fails: the scores stay plausible.

```python
import json, random, re, sqlite3, statistics, struct
import numpy as np                                  # numpy 2: bitwise_count
idx = json.load(open(RES + "/semantic-vectors-index.json"))

def numeric_part(doc_id):
    digits = doc_id[1:]
    if not doc_id.startswith("d") or not digits.isdigit(): return None
    if len(digits) > 1 and digits[0] == "0": return None
    return int(digits)

row_of, doc_of = {}, {}
for v in idx["volumes"]:
    ids = []
    for seg in v["seg"]:
        assert seg["s"] == len(ids)
        ids.append(seg["i"])
        if seg["n"] > 1:
            base = numeric_part(seg["i"])
            ids.extend(f"d{base + k}" for k in range(1, seg["n"]))
    assert len(ids) == v["n"]                       # the round trip, for every volume
    for k, d in enumerate(ids):
        row_of[(v["v"], d)] = v["r"] + k
        doc_of[v["r"] + k] = (v["v"], d)

blob = open(RES + "/semantic-vectors-binary.bin", "rb").read()
ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20])
digests = {"index": idx["provenanceDigest"], "binary": blob[20:52].hex(),
           "map": open(RES + "/semantic-map.bin", "rb").read(52)[20:52].hex(),
           "manifest": json.load(open(RES + "/semantic-shards-manifest.json"))["provenanceDigest"]}
assert len(set(digests.values())) == 1, digests
```

**Neighbours, and the two baselines** (§A.5). A neighbour is read against the k-th-neighbour
distribution, and a set's cohesion against random pairs. With numpy 2 a full Hamming scan takes
milliseconds. Without numpy, `bin(x).count("1")` over `int.from_bytes(row, "big")` does the same
on Python 3.9, which has no `int.bit_count()`, at a few seconds a scan.

```python
bits = np.frombuffer(blob, dtype=">u8", count=docs * dims // 64, offset=64).reshape(docs, dims // 64)
ED2 = ("frus1951-54IranEd2", "frus1969-76ve15p2Ed2")   # their first editions are in the corpus
skip = np.array([doc_of[r][0] in ED2 for r in range(docs)])

def distances(row):
    d = np.bitwise_count(bits ^ bits[row]).sum(axis=1).astype(np.int64)
    d[skip] = 1 << 20
    d[row] = 1 << 20
    return d

def nearest(key, k=25):                            # ties go by row, so a tie at the k-th place
    d = distances(row_of[key])                      # can differ from §A.5's printed list
    return [(int(d[r]), doc_of[int(r)]) for r in np.argsort(d, kind="stable")[:k]]

rng = random.Random(1877)
pairs = [int(np.bitwise_count(bits[rng.randrange(docs)] ^ bits[rng.randrange(docs)]).sum())
         for _ in range(20000)]
mean, sd = statistics.mean(pairs), statistics.pstdev(pairs)
first_pct = sorted(pairs)[len(pairs) // 100]
kth = sorted(int(np.sort(distances(r))[24]) for r in random.Random(1878).sample(range(docs), 200))
```

**The three-flag join** ([§14.17](#1417-the-second-finding-aid-when-the-vectors-enter-the-pass)
step 2). `scope` is the set of `(volume_id, document_id)` pairs you have built, and `literal` a
regex for the question's own word, compiled with `re.I`.

```python
con = sqlite3.connect("file:" + DB + "?mode=ro", uri=True)
def joined(key):
    return con.execute(
        "SELECT c.header, c.body_text, t.date_iso FROM document_cache c LEFT JOIN document_dates t "
        "ON t.volume_id = c.volume_id AND t.document_id = c.document_id "
        "WHERE c.volume_id = ? AND c.document_id = ?", key).fetchone()

def flagged(anchor, scope, literal, k=25):
    a_date = (joined(anchor) or ("", "", ""))[2] or ""
    rows = []
    for h, key in nearest(anchor, k):
        row = joined(key)
        if row is None:                             # Tier 1 covers volumes this database lacks
            rows.append((h, key, "NOT IN THIS DATABASE"))
            continue
        header, body, date = row
        rows.append((h, key, date,
                     "IN-SCOPE" if key in scope else "OUTSIDE",
                     "SAME-DECADE" if date and date[:3] == a_date[:3] else "OTHER-DECADE",
                     "LITERAL" if literal.search(header + " " + body) else "ABSENT"))
    return rows
```

**Near-duplicates before any count** ([§14.9](#149-where-the-corpus-double-counts-itself)). Read
both documents of every pair the check returns, and count a pair once only when the two texts agree.

```python
line = mean - 8 * sd
def near_duplicates(scope):
    rows = sorted(row_of[k] for k in scope if k in row_of)
    found = []
    for i, a in enumerate(rows[:-1]):
        d = np.bitwise_count(bits[rows[i + 1:]] ^ bits[a]).sum(axis=1)
        found += [(int(h), doc_of[a], doc_of[b]) for h, b in zip(d, rows[i + 1:]) if h < line]
    return sorted(found)
```

**The map**, when §14.10's label test needs it. A document's cluster is the uint16 at byte
`64 + 6 * row + 4` of `semantic-map.bin`. Its labels and era histogram are in
`semantic-map-index.json`: read that file's top-level keys before writing the accessor. Tier-2
reranking (§A.6) and free-text queries (§A.7) are in the guide.
