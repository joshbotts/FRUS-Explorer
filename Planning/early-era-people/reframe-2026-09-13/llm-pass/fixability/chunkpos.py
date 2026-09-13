#!/usr/bin/env python3
"""MEASURED: where the filtered sweep's hits and FPs sit relative to the sweep's own chunk windows
(harvest_embeddings.chunk with CHUNK_CHARS=3200, OVERLAP_CHARS=480 as in run-manifest.json), on the 64 gold docs;
and whether the resolving evidence for the hand-listed 'wider context' FPs lay in the same chunk."""
import os, sys, json, collections
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/Planning/early-era-people/feasibility-2026-09-12/measure-grains")
import grains as G
sd = G.sd
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
import harvest_embeddings as he
he.CHUNK_CHARS = 3200; he.OVERLAP_CHARS = 480
gold, bands = sd.load_ground_truth(os.environ["GROUND_TRUTH"])
FS = sd.collect_predictions(*G.STORES["filtered_sweep"], gold, True)[0]
FC = sd.collect_predictions(*G.STORES["filtered_control"], gold, True)[0]
stat = {"docs": 0, "docs_multi_chunk": 0, "chars": 0}
pos = {a: collections.Counter() for a in ("filtered_sweep", "filtered_control")}
lens = []
for key, gs in sorted(gold.items()):
    text = sd.cached_volume_text(key[0])[key[1]]
    ch = list(he.chunk(text))
    stat["docs"] += 1; stat["chars"] += len(text); lens.append(len(text))
    if len(ch) > 1: stat["docs_multi_chunk"] += 1
    first_end = ch[0][1]
    for a, P in (("filtered_sweep", FS), ("filtered_control", FC)):
        pr = P.get(key, [])
        _, _, used, _ = sd.match(gs, pr)
        for i, (s, e, n) in enumerate(pr):
            where = "first_chunk_only" if e <= first_end else "beyond_first_chunk"
            pos[a][(where, "tp" if i in used else "fp")] += 1
    if key in (("frus1937v01", "d566"), ("frus1937v01", "d382"), ("frus1946v06", "d88")):
        def chunks_of(off): return [j for j, (c0, c1) in enumerate(ch) if c0 <= off < c1]
        for probe in ("Planes from President Harding", "sailing on the President Harding", "sold by Hunzedal", "Hunzedal Company",
                      "Commanding General Seville", "Consul at Seville", "Military Governor Bilbao", "Leg Cairo"):
            o = text.find(probe)
            if o >= 0: print(key, "chunks", [(c0, c1) for c0, c1 in ch], "|", probe, "@", o, "in chunk", chunks_of(o))
print(stat, "median chars", sorted(lens)[len(lens)//2], "max", max(lens))
for a, c in pos.items():
    for w in ("first_chunk_only", "beyond_first_chunk"):
        tp, fp = c[(w, "tp")], c[(w, "fp")]
        print(a, w, "tp", tp, "fp", fp, "precision %.3f" % (tp/(tp+fp) if tp+fp else 0))
json.dump({"stat": stat, "positions": {a: {"%s|%s" % k: v for k, v in c.items()} for a, c in pos.items()}}, open("chunkpos.json", "w"), indent=1)
