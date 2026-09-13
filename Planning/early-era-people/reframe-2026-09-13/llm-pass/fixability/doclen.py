#!/usr/bin/env python3
"""MEASURED: over the 267-volume scope, how many documents exceed one sweep chunk (len > CHUNK_CHARS+OVERLAP_CHARS = 3680),
and what share of characters lies outside a document's first chunk window (i.e. text the sweep saw without the heading)."""
import os, sys, json, collections
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
os.environ.setdefault("TEXT_DIR", os.path.expanduser("~/frus-semantic-raw/text"))
import ner_store as store, harvest_embeddings as he
he.CHUNK_CHARS = 3200; he.OVERLAP_CHARS = 480
scope = json.load(open(os.path.expanduser("~/frus-ner-raw/scope.json")))
vols = scope["volumes"] if isinstance(scope, dict) and "volumes" in scope else scope
vols = [v if isinstance(v, str) else v.get("volume") or v.get("id") for v in vols]
docs = multi = 0; chars = beyond = 0; chunks = 0; lens = []
for v in vols:
    for doc, text in store.volume_text(os.environ["TEXT_DIR"], v).items():
        n = len(text); docs += 1; chars += n; lens.append(n)
        ch = he.chunk(text); chunks += len(ch)
        if len(ch) > 1:
            multi += 1; beyond += n - ch[0][1]
lens.sort()
r = {"volumes": len(vols), "documents": docs, "characters": chars, "chunks": chunks, "documents_multi_chunk": multi,
     "share_documents_multi_chunk": round(multi/docs, 4), "characters_beyond_first_chunk": beyond, "share_characters_beyond_first_chunk": round(beyond/chars, 4),
     "median_doc_chars": lens[len(lens)//2], "p90_doc_chars": lens[int(len(lens)*0.9)], "p99_doc_chars": lens[int(len(lens)*0.99)], "max_doc_chars": lens[-1]}
print(json.dumps(r, indent=1)); json.dump(r, open("doclen.json", "w"), indent=1)
