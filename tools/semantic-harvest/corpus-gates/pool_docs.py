#!/usr/bin/env python3
"""Pool the full-corpus chunk-vector store into document vectors + shared matrices.

Pooling rule PINNED (spike-gates.json "pooling"): char-length-weighted mean of
unit-norm chunk vectors, L2-renormalized. Weight = (c1 - c0) from the chunk's meta
row. truncate() / int8_quantize() / pack_bits() are transcribed VERBATIM from
tools/semantic-harvest/spike_gates.py.

Reads /Users/jbotts/frus-semantic-raw (read-only). Writes to OUT (assess/pool/).
"""

import gzip
import hashlib
import json
import os
import re
import sys
import time

import numpy as np

STORE = os.path.expanduser(os.environ.get("STORE", "~/frus-semantic-raw"))
OUT = os.path.join(
    os.path.expanduser(os.environ.get("ASSESS_DIR", "~/frus-semantic-gates")), "pool")
DIM = 768
NORM_SAMPLE_TARGET = 50000

DOC_ID_RE = re.compile(r"^d[0-9]+$")
ORD_ID_RE = re.compile(r"^ord[0-9]+$")


# ------------------------------------------------- verbatim from spike_gates.py

def truncate(matrix, dims):
    cut = matrix[:, :dims]
    return cut / np.linalg.norm(cut, axis=1, keepdims=True)


def int8_quantize(matrix):
    scale = np.abs(matrix).max(axis=1) / 127.0
    q = np.clip(np.rint(matrix / scale[:, None]), -127, 127).astype(np.int8)
    return q, scale.astype(np.float32)


def pack_bits(matrix):
    return np.packbits(matrix >= 0, axis=1)


# ------------------------------------------------------------------------ main

def main():
    os.makedirs(OUT, exist_ok=True)
    t0 = time.time()
    manifest = json.load(open(os.path.join(STORE, "run-manifest.json")))
    assert manifest["dim"] == DIM

    heads = {}
    vols = sorted(f[:-len(".head.json")] for f in os.listdir(os.path.join(STORE, "vectors"))
                  if f.endswith(".head.json"))
    total_docs = total_chunks = 0
    for vol in vols:
        heads[vol] = json.load(open(os.path.join(STORE, "vectors", vol + ".head.json")))
        total_docs += heads[vol]["docs"]
        total_chunks += heads[vol]["chunks"]
    print("volumes=%d head_docs=%d head_chunks=%d" % (len(vols), total_docs, total_chunks),
          flush=True)

    doc_f32 = np.empty((total_docs, DIM), dtype=np.float32)
    keys = []          # dicts {"v","d","o","chars"}
    all_norms = np.empty(total_chunks, dtype=np.float64)  # raw chunk norms pre-normalization

    stats = {
        "volumes": len(vols),
        "head_totals": {"docs": total_docs, "chunks": total_chunks},
        "manifest_totals": {"docs": manifest["totals_this_run"]["docs"],
                            "chunks": manifest["totals_this_run"]["chunks"]},
        "per_volume_mismatches": [],   # head vs actual bin/meta/text counts
        "nan_count": 0, "inf_count": 0,
        "zero_chunk_vectors": 0,       # exact all-zero chunk rows
        "zero_norm_pooled_docs": 0,
        "zero_weight_docs": 0,         # weight sum == 0 (would break pinned rule)
        "doc_id_nonstandard": 0,       # not ^d[0-9]+$
        "doc_id_ord_fallback": 0,      # ^ord[0-9]+$
        "key_collisions": [],          # (vol, d) appearing twice as a doc row
        "meta_text_order_mismatch": [],
        "tiling": {"ci_not_dense": 0, "c0_first_nonzero": 0,
                   "c1_last_ne_textlen": 0, "no_overlap": 0,
                   "meta_o_mismatch": 0},
        "tiling_examples": {"ci_not_dense": [], "c0_first_nonzero": [],
                            "c1_last_ne_textlen": [], "no_overlap": [],
                            "meta_o_mismatch": []},
        "nonstandard_id_examples": [],
    }

    seen_keys = {}
    row = 0
    chunk_cursor = 0
    keys_fh = open(os.path.join(OUT, "doc_keys.jsonl"), "w")

    for vi, vol in enumerate(vols):
        head = heads[vol]
        vecs = np.fromfile(os.path.join(STORE, "vectors", vol + ".bin"), dtype="<f4")
        if vecs.size % DIM:
            stats["per_volume_mismatches"].append(
                {"volume": vol, "what": "bin size not a multiple of dim",
                 "floats": int(vecs.size)})
            continue
        vecs = vecs.reshape(-1, DIM)
        meta = [json.loads(line) for line in
                open(os.path.join(STORE, "vectors", vol + ".meta.jsonl"))]
        with gzip.open(os.path.join(STORE, "text", vol + ".jsonl.gz"), "rt",
                       encoding="utf-8") as fh:
            docs = [json.loads(line) for line in fh]
        if len(meta) != head["chunks"] or vecs.shape[0] != head["chunks"]:
            stats["per_volume_mismatches"].append(
                {"volume": vol, "what": "chunk count", "head": head["chunks"],
                 "meta": len(meta), "bin": int(vecs.shape[0])})
        if len(docs) != head["docs"]:
            stats["per_volume_mismatches"].append(
                {"volume": vol, "what": "doc count", "head": head["docs"],
                 "text": len(docs)})

        nan_n = int(np.isnan(vecs).sum())
        inf_n = int(np.isinf(vecs).sum())
        stats["nan_count"] += nan_n
        stats["inf_count"] += inf_n

        norms = np.linalg.norm(vecs.astype(np.float64), axis=1)
        n_ch = vecs.shape[0]
        all_norms[chunk_cursor:chunk_cursor + n_ch] = norms
        chunk_cursor += n_ch
        zero_rows = int((norms == 0.0).sum())
        stats["zero_chunk_vectors"] += zero_rows

        # unit-normalize each chunk row (guard zero-norm rows: leave as zeros)
        safe = np.where(norms == 0.0, 1.0, norms)
        unit = (vecs.astype(np.float64) / safe[:, None])

        # group consecutive meta rows by d in file order
        runs = []  # (d, start, end) half-open
        for i, m in enumerate(meta):
            if runs and runs[-1][0] == m["d"]:
                runs[-1][2] = i + 1
            else:
                runs.append([m["d"], i, i + 1])

        text_d = [doc["d"] for doc in docs]
        run_d = [r[0] for r in runs]
        if run_d != text_d:
            stats["meta_text_order_mismatch"].append(
                {"volume": vol, "runs": len(runs), "docs": len(docs)})
            # fall back to spike_gates dict grouping keyed off text order
            by_doc = {}
            for i, m in enumerate(meta):
                by_doc.setdefault(m["d"], []).append(i)
            runs = None
        doc_text_len = {doc["d"]: len(doc["t"]) for doc in docs}

        for di, doc in enumerate(docs):
            d = doc["d"]
            tlen = len(doc["t"])
            if runs is not None:
                _, s, e = runs[di]
                idxs = list(range(s, e))
            else:
                idxs = by_doc.get(d, [])
            rows_meta = [meta[i] for i in idxs]

            # --- tiling checks
            cis = [m["ci"] for m in rows_meta]
            if cis != list(range(len(cis))):
                stats["tiling"]["ci_not_dense"] += 1
                if len(stats["tiling_examples"]["ci_not_dense"]) < 3:
                    stats["tiling_examples"]["ci_not_dense"].append(
                        {"v": vol, "d": d, "ci": cis[:8]})
            if rows_meta and rows_meta[0]["c0"] != 0:
                stats["tiling"]["c0_first_nonzero"] += 1
                if len(stats["tiling_examples"]["c0_first_nonzero"]) < 3:
                    stats["tiling_examples"]["c0_first_nonzero"].append(
                        {"v": vol, "d": d, "c0": rows_meta[0]["c0"]})
            if rows_meta and rows_meta[-1]["c1"] != tlen:
                stats["tiling"]["c1_last_ne_textlen"] += 1
                if len(stats["tiling_examples"]["c1_last_ne_textlen"]) < 3:
                    stats["tiling_examples"]["c1_last_ne_textlen"].append(
                        {"v": vol, "d": d, "c1": rows_meta[-1]["c1"], "len": tlen})
            for a, b in zip(rows_meta, rows_meta[1:]):
                if not (b["c0"] < a["c1"]):
                    stats["tiling"]["no_overlap"] += 1
                    if len(stats["tiling_examples"]["no_overlap"]) < 3:
                        stats["tiling_examples"]["no_overlap"].append(
                            {"v": vol, "d": d, "c1_prev": a["c1"], "c0_next": b["c0"]})
                    break
            if any(m["o"] != doc["o"] for m in rows_meta):
                stats["tiling"]["meta_o_mismatch"] += 1
                if len(stats["tiling_examples"]["meta_o_mismatch"]) < 3:
                    stats["tiling_examples"]["meta_o_mismatch"].append(
                        {"v": vol, "d": d, "doc_o": doc["o"],
                         "meta_o": sorted({m["o"] for m in rows_meta})})

            # --- id hygiene
            if not DOC_ID_RE.match(d):
                stats["doc_id_nonstandard"] += 1
                if ORD_ID_RE.match(d):
                    stats["doc_id_ord_fallback"] += 1
                if len(stats["nonstandard_id_examples"]) < 10:
                    stats["nonstandard_id_examples"].append({"v": vol, "d": d})
            if (vol, d) in seen_keys:
                stats["key_collisions"].append({"v": vol, "d": d,
                                                "rows": [seen_keys[(vol, d)], row]})
            else:
                seen_keys[(vol, d)] = row

            # --- PINNED pooling: char-length-weighted mean of unit-norm chunks,
            # L2-renormalized
            weights = np.array([m["c1"] - m["c0"] for m in rows_meta], dtype=np.float64)
            stacked = unit[idxs]
            wsum = weights.sum()
            if wsum == 0.0:
                stats["zero_weight_docs"] += 1
                pooled = stacked.mean(axis=0) if len(idxs) else np.zeros(DIM)
            else:
                pooled = (stacked * weights[:, None]).sum(axis=0) / wsum
            norm = np.linalg.norm(pooled)
            if norm == 0.0:
                stats["zero_norm_pooled_docs"] += 1
                doc_f32[row] = 0.0
            else:
                doc_f32[row] = (pooled / norm).astype(np.float32)
            rec = {"v": vol, "d": d, "o": doc["o"], "chars": tlen}
            keys.append(rec)
            keys_fh.write(json.dumps(rec, separators=(",", ":")) + "\n")
            row += 1

        if (vi + 1) % 50 == 0 or vi + 1 == len(vols):
            print("  [%d/%d] %s rows=%d chunks=%d %.0fs" %
                  (vi + 1, len(vols), vol, row, chunk_cursor, time.time() - t0),
                  flush=True)

    keys_fh.close()
    stats["docs_pooled"] = row
    stats["chunks_read"] = chunk_cursor
    assert row == total_docs, (row, total_docs)
    doc_f32 = doc_f32[:row]
    np.save(os.path.join(OUT, "doc_f32_768.npy"), doc_f32)
    print("f32 matrix saved (%.1f MB) %.0fs" % (doc_f32.nbytes / 1e6, time.time() - t0),
          flush=True)

    # raw chunk-norm distribution, ~50k sample spread across volumes (global stride)
    stride = max(1, chunk_cursor // NORM_SAMPLE_TARGET)
    sample = all_norms[:chunk_cursor:stride]
    stats["raw_chunk_norms"] = {
        "sample_n": int(sample.size), "sample_stride": stride,
        "sample_min": float(sample.min()), "sample_median": float(np.median(sample)),
        "sample_max": float(sample.max()),
        "full_min": float(all_norms[:chunk_cursor].min()),
        "full_median": float(np.median(all_norms[:chunk_cursor])),
        "full_max": float(all_norms[:chunk_cursor].max()),
    }

    # pooled-matrix hygiene
    stats["pooled_nan_count"] = int(np.isnan(doc_f32).sum())
    stats["pooled_inf_count"] = int(np.isinf(doc_f32).sum())
    pooled_norms = np.linalg.norm(doc_f32.astype(np.float64), axis=1)
    stats["pooled_norm_min"] = float(pooled_norms.min())
    stats["pooled_norm_max"] = float(pooled_norms.max())

    # ------------------------------------------------ truncation + quantization
    for dims in (256, 512):
        cut = truncate(doc_f32, dims).astype(np.float32)
        q, scale = int8_quantize(cut)
        np.save(os.path.join(OUT, "doc_int8_%d.npy" % dims), q)
        np.save(os.path.join(OUT, "doc_scale_%d.npy" % dims), scale)
        stats["int8_%d" % dims] = {
            "nan_in_cut": int(np.isnan(cut).sum()),
            "scale_min": float(scale.min()), "scale_max": float(scale.max()),
            "zero_scales": int((scale == 0).sum()),
        }
        if dims == 256:
            bits = pack_bits(cut)
            np.save(os.path.join(OUT, "doc_bits_256.npy"), bits)
            # ---- duplicate int8-256 rows
            groups = {}
            qc = np.ascontiguousarray(q)
            for i in range(qc.shape[0]):
                h = hashlib.blake2b(qc[i].tobytes(), digest_size=16).digest()
                groups.setdefault(h, []).append(i)
            dup_groups = [g for g in groups.values() if len(g) > 1]
            dup_rows = sum(len(g) for g in dup_groups)
            dup_groups.sort(key=lambda g: g[0])
            with open(os.path.join(OUT, "dup_int8_rows.jsonl"), "w") as fh:
                for g in dup_groups:
                    fh.write(json.dumps(
                        {"rows": [{"v": keys[i]["v"], "d": keys[i]["d"]} for i in g]},
                        separators=(",", ":")) + "\n")
            stats["dup_int8_256"] = {
                "groups": len(dup_groups), "rows_in_groups": dup_rows,
                "rate": round(dup_rows / max(1, row), 5),
                "examples": [
                    [{"v": keys[i]["v"], "d": keys[i]["d"]} for i in g]
                    for g in dup_groups[:5]],
            }
        del cut, q
        print("dims=%d done %.0fs" % (dims, time.time() - t0), flush=True)

    stats["elapsed_secs"] = round(time.time() - t0, 1)
    json.dump(stats, open(os.path.join(OUT, "pool_stats.json"), "w"),
              indent=2, sort_keys=True)
    print("DONE", flush=True)
    print(json.dumps({k: v for k, v in stats.items()
                      if k not in ("tiling_examples", "nonstandard_id_examples")},
                     indent=2, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
