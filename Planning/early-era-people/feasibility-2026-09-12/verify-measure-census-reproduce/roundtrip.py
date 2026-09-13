import json, os, gzip, subprocess, hashlib
D = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/measure-census"
c = json.load(open(D + "/census.json")); v = json.load(open("verify.json"))
for a, ca in c["arms"].items():
    p = D + "/artifact-%s.json" % a; gz = p + ".gz"
    art = json.load(open(p, encoding="utf-8"))
    vols = len(art["r"]); docs = sum(len(dd) for dd in art["r"].values()); pairs = sum(len(ids) for dd in art["r"].values() for ids in dd.values())
    used = set(i for dd in art["r"].values() for ids in dd.values() for i in ids)
    vocab = len(art["s"]); all_used = used == set(range(vocab)); dupfree = all(len(ids) == len(set(ids)) for dd in art["r"].values() for ids in dd.values())
    # gz round trip: decompressed bytes identical to raw
    raw = open(p, "rb").read(); dec = gzip.open(gz, "rb").read()
    print(a, "vols", vols, "docs", docs, pairs, "vocab", vocab, "all_ids_used", all_used, "no_dup_ids", dupfree,
          "bytes", os.path.getsize(p), ca["artifact"]["bytes"], "gz", os.path.getsize(gz), ca["artifact"]["gzip_bytes"], "gz_roundtrip", raw == dec,
          "MATCH_CENSUS", (vols, docs, pairs, vocab) == (267, ca["docs_with_mention"], ca["pairs_volume_doc_K2"], ca["artifact"]["vocab_size"]),
          "MATCH_MINE", (docs, pairs, vocab) == (v["arms"][a]["docs"], v["arms"][a]["pairs"], v["arms"][a]["K2"]))
