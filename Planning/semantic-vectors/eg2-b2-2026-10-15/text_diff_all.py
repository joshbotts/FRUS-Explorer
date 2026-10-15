import gzip, json, os
A = os.path.expanduser("~/frus-semantic-raw")
B = os.path.expanduser("~/frus-semantic-raw-embeddinggemma-2")
def load(root, vol):
    with gzip.open(os.path.join(root, "text", vol + ".jsonl.gz"), "rt", encoding="utf-8") as fh:
        return [json.loads(l) for l in fh]
vols = sorted(f[:-len(".jsonl.gz")] for f in os.listdir(os.path.join(B, "text")) if f.endswith(".jsonl.gz"))
va = sorted(f[:-len(".jsonl.gz")] for f in os.listdir(os.path.join(A, "text")) if f.endswith(".jsonl.gz"))
print("volumes", len(vols), len(va), "same set", vols == va)
tot_docs = tot_diff_docs = 0
diff_chunks = 0
out = []
for vol in vols:
    a, b = load(A, vol), load(B, vol)
    assert [d["d"] for d in a] == [d["d"] for d in b], vol
    ma = open(os.path.join(A, "vectors", vol + ".meta.jsonl")).read().splitlines()
    mb = open(os.path.join(B, "vectors", vol + ".meta.jsonl")).read().splitlines()
    tot_docs += len(a)
    dd = [(x["d"], len(y["t"]) - len(x["t"])) for x, y in zip(a, b) if x["t"] != y["t"]]
    other = [x["d"] for x, y in zip(a, b) if {k: v for k, v in x.items() if k != "t"} != {k: v for k, v in y.items() if k != "t"}]
    # chunks whose text differs: compare the chunk substrings
    ja = [json.loads(l) for l in ma]; jb = [json.loads(l) for l in mb]
    texts_a = {x["d"]: x["t"] for x in a}; texts_b = {x["d"]: x["t"] for x in b}
    nchunk = 0
    if len(ja) == len(jb):
        for x, y in zip(ja, jb):
            if texts_a[x["d"]][x["c0"]:x["c1"]] != texts_b[y["d"]][y["c0"]:y["c1"]]:
                nchunk += 1
    else:
        nchunk = -1
    if dd or other or len(ja) != len(jb):
        tot_diff_docs += len(dd)
        diff_chunks += max(nchunk, 0)
        out.append({"volume": vol, "docs_text_differ": len(dd), "char_delta": sum(x[1] for x in dd),
                    "docs": [x[0] for x in dd][:40], "other_fields_differ": other[:10],
                    "chunks_a": len(ja), "chunks_b": len(jb), "chunks_text_differ": nchunk})
print("docs", tot_docs, "docs with different text", tot_diff_docs, "chunks with different text", diff_chunks)
for o in out: print(json.dumps(o))
json.dump(out, open(os.path.expanduser("~/frus-b2/text-diff-all.json"), "w"), indent=1)
