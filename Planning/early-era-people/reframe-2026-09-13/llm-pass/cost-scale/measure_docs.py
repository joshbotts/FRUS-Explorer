#!/usr/bin/env python3
"""Shapes A/B inputs: per-document R-0 chars, candidate union per document, Qwen token anchor.
Read-only over ~/frus-semantic-raw/text, ~/frus-ner-raw (marked, scope), filtered control,
filtered sweep, and the raw sweep's detected/*.head.json. Writes docs.tsv + anchor.json here."""
import os, sys, json, time
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, REPO + "/tools/semantic-harvest")
import ner_store
HERE = os.path.dirname(os.path.abspath(__file__))
H = os.path.expanduser
TEXT = H("~/frus-semantic-raw/text")
MARKED = H("~/frus-ner-raw")
FCTRL = H("~/frus-ner-raw-control-filtered")
FSWEEP = H("~/frus-ner-raw-filtered")
RAWSWEEP = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw"
CHUNK_CHARS, OVERLAP_CHARS = 3200, 480

def chunk(text):  # verbatim logic of harvest_embeddings.chunk
    if len(text) <= CHUNK_CHARS + OVERLAP_CHARS:
        return [(0, len(text))]
    spans, start = [], 0
    while start < len(text):
        end = min(start + CHUNK_CHARS, len(text))
        if end < len(text):
            space = text.rfind(" ", start + CHUNK_CHARS // 2, end)
            if space != -1:
                end = space
        spans.append((start, end))
        if end >= len(text):
            break
        nxt = end - OVERLAP_CHARS
        space = text.find(" ", nxt)
        start = space + 1 if (space != -1 and space < end) else end
    return spans

def merged_groups(iv):
    iv = sorted(iv); n = 0; cur = -1
    for s, e in iv:
        if s >= cur:
            n += 1; cur = e
        else:
            cur = max(cur, e)
    return n

vols = ner_store.scope_volumes(MARKED)
out = open(os.path.join(HERE, "docs.tsv"), "w")
out.write("vol\tdoc\tchars\tchunks\tchunk_chars\tmarked\tfctrl\tfsweep\tunion_exact\tunion_merged\tunion_surfaces\tunion_surface_chars\tunion_span_chars\n")
anchor = []
t0 = time.time()
tot_docs = 0
for i, v in enumerate(vols):
    texts = ner_store.volume_text(TEXT, v)
    layers = {}
    for name, store, layer in (("marked", MARKED, "marked"), ("fctrl", FCTRL, "detected"), ("fsweep", FSWEEP, "detected")):
        by = {}
        for r in ner_store.volume_layer(store, layer, v):
            by.setdefault(r["d"], []).append((r["s"], r["e"], r["n"]))
        layers[name] = by
    mdocs = set(d for d in texts)
    vc = vcc = 0
    for d, t in texts.items():
        L = len(t)
        ch = chunk(t) if L else []
        cc = sum(b - a for a, b in ch)
        vc += len(ch); vcc += cc
        m = layers["marked"].get(d, []); c = layers["fctrl"].get(d, []); s = layers["fsweep"].get(d, [])
        u = {}
        for (a, b, n) in m + c + s:
            u[(a, b)] = n
        surf = {}
        for n in u.values():
            surf.setdefault(n.casefold(), n)
        out.write("%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n" % (
            v, d, L, len(ch), cc, len(set((a, b) for a, b, _ in m)), len(set((a, b) for a, b, _ in c)),
            len(set((a, b) for a, b, _ in s)), len(u), merged_groups(list(u.keys())), len(surf),
            sum(len(x) for x in surf.values()), sum(len(n) for n in u.values())))
        tot_docs += 1
    h = json.load(open(os.path.join(RAWSWEEP, "detected", v + ".head.json")))
    anchor.append({"vol": v, "docs_text": len(texts), "chunks_recon": vc, "chunk_chars_recon": vcc,
                   "head_chunks": h.get("chunks"), "head_chars": h.get("chars_scanned"),
                   "prompt_tokens": h.get("prompt_tokens"), "completion_tokens": h.get("completion_tokens"),
                   "mentions": h.get("mentions"), "returned": h.get("returned"), "truncated": h.get("truncated"),
                   "secs": h.get("secs"), "docs_scanned": h.get("docs_scanned")})
    if i % 25 == 0:
        print(i, v, tot_docs, round(time.time() - t0), flush=True)
out.close()
json.dump(anchor, open(os.path.join(HERE, "anchor-per-volume.json"), "w"), indent=0)
print("done", tot_docs, round(time.time() - t0))
