import gzip, json, os, sys, difflib
A = os.path.expanduser("~/frus-semantic-raw")
B = os.path.expanduser("~/frus-semantic-raw-embeddinggemma-2")
def load(root, vol):
    with gzip.open(os.path.join(root, "text", vol + ".jsonl.gz"), "rt", encoding="utf-8") as fh:
        return [json.loads(l) for l in fh]
def meta(root, vol):
    return [json.loads(l) for l in open(os.path.join(root, "vectors", vol + ".meta.jsonl"))]
for vol in sys.argv[1:]:
    a, b = load(A, vol), load(B, vol)
    ma, mb = meta(A, vol), meta(B, vol)
    ha = json.load(open(os.path.join(A, "vectors", vol + ".head.json")))
    hb = json.load(open(os.path.join(B, "vectors", vol + ".head.json")))
    print("==", vol, "docs", len(a), len(b), "chunks", len(ma), len(mb), "chars", ha.get("chars"), hb.get("chars"))
    print("   head A", {k: ha[k] for k in ha if k not in ("model",)})
    print("   head B", {k: hb[k] for k in hb if k not in ("model",)})
    assert [d["d"] for d in a] == [d["d"] for d in b]
    for da, db in zip(a, b):
        if da["t"] != db["t"]:
            ca = [m for m in ma if m["d"] == da["d"]]
            cb = [m for m in mb if m["d"] == db["d"]]
            print("  doc", da["d"], "len", len(da["t"]), "->", len(db["t"]), "delta", len(db["t"]) - len(da["t"]),
                  "chunks", len(ca), len(cb), "spans equal", [(m["c0"], m["c1"]) for m in ca] == [(m["c0"], m["c1"]) for m in cb])
            sm = difflib.SequenceMatcher(None, da["t"], db["t"], autojunk=False)
            for op, i1, i2, j1, j2 in sm.get_opcodes():
                if op != "equal":
                    print("    %s A[%d:%d]=%r B[%d:%d]=%r" % (op, i1, i2, da["t"][max(0,i1-60):i2+60], j1, j2, db["t"][max(0,j1-60):j2+60]))
        other = {k for k in set(da) | set(db) if k != "t" and da.get(k) != db.get(k)}
        if other:
            print("  doc", da["d"], "other fields differ", other, {k: (da.get(k), db.get(k)) for k in other})
