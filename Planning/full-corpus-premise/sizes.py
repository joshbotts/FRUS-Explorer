#!/usr/bin/env python3
"""Bytes and file counts of each surface of the app's data on this Mac, read-only
(Planning/Agentic-Guide-Full-Corpus-Premise-Assessment-2026-11-02.md §2.1).

    python3 -I sizes.py <app data folder> <bundle Resources folder>

The app data folder is the container's Application Support/FRUSExplorer. Bytes are st_size; "on
disk" is st_blocks x 512, which is smaller for the bundle's compressed files."""
import os, sys, json
def tree(path, pred=lambda p: True):
    n = b = blocks = 0
    for root, dirs, files in os.walk(path):
        for f in files:
            p = os.path.join(root, f)
            if not pred(p): continue
            st = os.lstat(p)
            n += 1; b += st.st_size; blocks += st.st_blocks * 512
    return n, b, blocks
C, R = sys.argv[1], sys.argv[2]
V = os.path.join(C, "volumes")
rows = []
rows.append(("TEI XML (volumes/*.xml)",) + tree(V, lambda p: p.endswith(".xml") and os.path.dirname(p) == V))
rows.append(("figure images (volumes/*.figures/)",) + tree(V, lambda p: ".figures/" in p))
rows.append(("figure completion record",) + tree(V, lambda p: p.endswith(".figure-images-complete.json")))
rows.append(("Tier-2 shards (SemanticVectors/*.vec)",) + tree(os.path.join(C, "SemanticVectors"), lambda p: p.endswith(".vec")))
rows.append(("SemanticVectors/ other files",) + tree(os.path.join(C, "SemanticVectors"), lambda p: not p.endswith(".vec")))
rows.append(("SemanticModel/ (query encoder)",) + tree(os.path.join(C, "SemanticModel")))
for f in ("frus.db", "frus.db-wal", "frus.db-shm"):
    rows.append((f,) + tree(C, lambda p, f=f: os.path.basename(p) == f and os.path.dirname(p) == C))
rows.append(("bundle Resources/*.json",) + tree(R, lambda p: p.endswith(".json") and os.path.dirname(p) == R))
rows.append(("bundle Resources/semantic-*.bin",) + tree(R, lambda p: os.path.basename(p).startswith("semantic-") and p.endswith(".bin") and os.path.dirname(p) == R))
rows.append(("bundle Resources/ (everything)",) + tree(R))
for name, n, b, blk in rows:
    print(f"{name:42s} {n:6d} files {b:15,d} bytes ({b/1e9:7.3f} GB) on disk {blk/1e9:7.3f} GB")
