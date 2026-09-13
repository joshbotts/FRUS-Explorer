#!/usr/bin/env python3
"""Surface census over the local NER stores (#234 feasibility, label measure-census).

Streams one volume at a time across every arm. Stdlib only. Read-only on every store.
Writes census.json + one compact artifact per arm (plus .gz) into OUT_DIR.
"""
import gzip, json, os, re, statistics, sys, time
from collections import Counter

sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
import ner_store  # band_of, layer_path, read_jsonl_gz, layer_head

HOME = os.path.expanduser("~")
STUDIO = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw"
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

ARMS = {  # label -> (store, layer, expected row total)
    "marked":           (os.path.join(HOME, "frus-ner-raw"), "marked", 245747),
    "raw_control":      (os.path.join(HOME, "frus-ner-raw-control"), "detected", 1353849),
    "filtered_control": (os.path.join(HOME, "frus-ner-raw-control-filtered"), "detected", 1261852),
    "raw_sweep":        (STUDIO, "detected", 3656238),
    "filtered_sweep":   (os.path.join(HOME, "frus-ner-raw-filtered"), "detected", 2597043),
}
UNIONS = {  # label -> component arms (union at the (volume, doc, K2) grain)
    "union_marked_filtered_control": ("marked", "filtered_control"),
    "union_marked_filtered_sweep":   ("marked", "filtered_sweep"),
}
ALL = list(ARMS) + list(UNIONS)

HONORIFICS = ["mr", "mrs", "miss", "dr", "sir", "hon", "general", "colonel", "captain", "major",
              "admiral", "señor", "monsieur", "herr", "mme", "messrs", "rev", "judge", "governor",
              "president", "minister", "count", "baron", "lord", "lady", "prince", "king", "queen", "m."]
# Tokens listed without a period accept an optional trailing period; "m." requires its period.
_alts = [re.escape(h[:-1]) + r"\." if h.endswith(".") else re.escape(h) + r"\.?" for h in HONORIFICS]
HONORIFIC_RE = re.compile(r"^(?:" + "|".join(_alts) + r")\s+")
WS_RE = re.compile(r"\s+")
POSS_RE = re.compile(r"(?:’s|'s|’|')$")

def k1(surface):
    s = WS_RE.sub(" ", surface.casefold()).strip()
    s = POSS_RE.sub("", s).strip()
    return s

def k2(key1):
    return HONORIFIC_RE.sub("", key1, count=1).strip() or key1

class ArmAcc:
    def __init__(self, label):
        self.label = label
        self.rows = 0                     # rows read (unions: rows contributed by both components)
        self.rows_dedup_span = 0          # unions only: distinct (doc, s, e) over both components
        self.k1 = Counter()               # K1 -> mention count
        self.k2 = Counter()               # K2 -> mention count
        self.pairs = 0                    # distinct (volume, doc, K2)
        self.docs_with_mention = 0
        self.docs_by_band = Counter()
        self.mentions_by_band = Counter()
        self.pairs_by_band = Counter()
        self.docs_only_fromto = 0         # docs whose every row is a marked from/to row
        self.per_volume_k2 = {}           # volume -> distinct K2 in volume
        self.per_volume_pairs = {}
        self.per_volume_docs = {}
        self.typed = Counter()            # marked only: t -> count
        self.head_mismatch = []
        self.vocab = {}                   # K2 -> id (first appearance)
        path = os.path.join(OUT_DIR, "artifact-%s.json" % label)
        self.path = path
        self.fh = open(path, "w", encoding="utf-8")
        self.fh.write('{"r":{')
        self.first_vol = True

    def add_volume(self, volume, band, doc_rows, typed_rows_only):
        """doc_rows: {doc: [(K2, is_marked_fromto), ...]} for this volume."""
        vol_k2 = set()
        vol_pairs = 0
        vol_entries = []
        for doc in sorted(doc_rows):
            entries = doc_rows[doc]
            keys = sorted({k for k, _ in entries})
            vol_k2.update(keys)
            vol_pairs += len(keys)
            if all(ft for _, ft in entries):
                self.docs_only_fromto += 1
            ids = []
            for k in keys:
                if k not in self.vocab:
                    self.vocab[k] = len(self.vocab)
                ids.append(self.vocab[k])
            vol_entries.append('%s:%s' % (json.dumps(doc, ensure_ascii=False), json.dumps(ids, separators=(",", ":"))))
        self.pairs += vol_pairs
        self.pairs_by_band[band] += vol_pairs
        self.docs_with_mention += len(doc_rows)
        self.docs_by_band[band] += len(doc_rows)
        self.per_volume_k2[volume] = len(vol_k2)
        self.per_volume_pairs[volume] = vol_pairs
        self.per_volume_docs[volume] = len(doc_rows)
        if not self.first_vol:
            self.fh.write(",")
        self.first_vol = False
        self.fh.write('%s:{%s}' % (json.dumps(volume), ",".join(vol_entries)))

    def finish(self):
        vocab = [None] * len(self.vocab)
        for k, i in self.vocab.items():
            vocab[i] = k
        self.fh.write('},"s":' + json.dumps(vocab, ensure_ascii=False, separators=(",", ":")) + '}')
        self.fh.close()
        gz = self.path + ".gz"
        with open(self.path, "rb") as src, open(gz, "wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=9, mtime=0) as dst:
            while True:
                chunk = src.read(1 << 20)
                if not chunk:
                    break
                dst.write(chunk)
        return os.path.getsize(self.path), os.path.getsize(gz)

def concentration(counter):
    total = sum(counter.values())
    single = sum(c for c in counter.values() if c == 1)
    ge5 = sum(c for c in counter.values() if c >= 5)
    ge20 = sum(c for c in counter.values() if c >= 20)
    return {
        "mentions": total,
        "distinct": len(counter),
        "mentions_in_singleton_surfaces": single, "share_singleton": round(single / total, 4) if total else None,
        "mentions_in_surfaces_ge5": ge5, "share_ge5": round(ge5 / total, 4) if total else None,
        "mentions_in_surfaces_ge20": ge20, "share_ge20": round(ge20 / total, 4) if total else None,
        "surfaces_singleton": sum(1 for c in counter.values() if c == 1),
        "surfaces_ge5": sum(1 for c in counter.values() if c >= 5),
        "surfaces_ge20": sum(1 for c in counter.values() if c >= 20),
        "top30": counter.most_common(30),
    }

def main():
    t0 = time.time()
    volumes = ner_store.scope_volumes(ARMS["marked"][0])
    assert len(volumes) == 267, len(volumes)
    accs = {label: ArmAcc(label) for label in ALL}
    docs_total = 0
    docs_by_band = Counter()
    head_docs_mismatch = []
    for i, volume in enumerate(volumes):
        band = ner_store.band_of(volume)
        marked_head = ner_store.layer_head(ARMS["marked"][0], "marked", volume)
        n_docs = marked_head["docs"]
        docs_total += n_docs
        docs_by_band[band] += n_docs
        per_arm_docrows = {}
        for label, (store, layer, _) in ARMS.items():
            acc = accs[label]
            path = ner_store.layer_path(store, layer, volume)
            if path is None:
                acc.head_mismatch.append((volume, "missing file"))
                rows = []
            else:
                rows = ner_store.read_jsonl_gz(path)
            head = ner_store.layer_head(store, layer, volume)
            head_docs = head.get("docs", head.get("docs_in_volume")) if head else None
            if head_docs != n_docs:
                head_docs_mismatch.append((label, volume, head_docs, n_docs))
            if head is None or head.get("mentions") != len(rows):
                acc.head_mismatch.append((volume, head.get("mentions") if head else None, len(rows)))
            acc.rows += len(rows)
            acc.mentions_by_band[band] += len(rows)
            doc_rows = {}
            for row in rows:
                key1 = k1(row["n"])
                key2 = k2(key1)
                acc.k1[key1] += 1
                acc.k2[key2] += 1
                is_ft = False
                if label == "marked":
                    t = row.get("t")
                    acc.typed[t if t in ("from", "to") else "untyped"] += 1
                    is_ft = t in ("from", "to")
                doc_rows.setdefault(row["d"], []).append((key2, is_ft, row["s"], row["e"]))
            per_arm_docrows[label] = doc_rows
            acc.add_volume(volume, band, {d: [(k, f) for k, f, _, _ in v] for d, v in doc_rows.items()}, None)
        for label, comps in UNIONS.items():
            acc = accs[label]
            merged = {}
            spans = set()
            for comp in comps:
                for d, v in per_arm_docrows[comp].items():
                    merged.setdefault(d, []).extend((k, f) for k, f, _, _ in v)
                    spans.update((d, s, e) for _, _, s, e in v)
                acc.rows += accs[comp].per_volume_rows_last
                acc.mentions_by_band[band] += accs[comp].per_volume_rows_last
                acc.k1.update(Counter())  # placeholder; union counters filled below
            acc.rows_dedup_span += len(spans)
            acc.add_volume(volume, band, merged, None)
        # union K1/K2 counters: sum of component counters is done at the end (cheaper)
        if (i + 1) % 25 == 0:
            print("  %d/%d volumes, %.0fs" % (i + 1, len(volumes), time.time() - t0), file=sys.stderr)
    # union counters = sum of components (rows contributed, not deduped)
    for label, comps in UNIONS.items():
        for comp in comps:
            accs[label].k1.update(accs[comp].k1)
            accs[label].k2.update(accs[comp].k2)
    result = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "scope": {"volumes": len(volumes), "documents": docs_total, "documents_by_band": dict(docs_by_band),
                  "source": "sum of docs over ~/frus-ner-raw/marked/<vol>.head.json (scope.json volume list)"},
        "honorifics": HONORIFICS,
        "keys": {"K1": "casefold + whitespace-collapse + strip trailing ’s/'s/’/'",
                 "K2": "K1 with ONE leading honorific (optional trailing period; 'm.' requires it) stripped; falls back to K1 if empty"},
        "head_docs_mismatch": head_docs_mismatch,
        "positive_controls": {},
        "arms": {},
        "elapsed_secs": None,
    }
    for label in ALL:
        acc = accs[label]
        raw_bytes, gz_bytes = acc.finish()
        k2vals = list(acc.per_volume_k2.values())
        pv = list(acc.per_volume_pairs.values())
        arm = {
            "rows": acc.rows,
            "mentions_by_band": dict(acc.mentions_by_band),
            "distinct_K1": len(acc.k1),
            "distinct_K2": len(acc.k2),
            "pairs_volume_doc_K2": acc.pairs,
            "pairs_by_band": dict(acc.pairs_by_band),
            "docs_with_mention": acc.docs_with_mention,
            "docs_with_mention_share": round(acc.docs_with_mention / docs_total, 4),
            "docs_with_mention_by_band": {b: {"docs": acc.docs_by_band[b], "share": round(acc.docs_by_band[b] / docs_by_band[b], 4)} for b in docs_by_band},
            "docs_only_marked_fromto": acc.docs_only_fromto,
            "docs_only_marked_fromto_share_of_docs_with_mention": round(acc.docs_only_fromto / acc.docs_with_mention, 4) if acc.docs_with_mention else None,
            "concentration_K2": concentration(acc.k2),
            "concentration_K1": {k: v for k, v in concentration(acc.k1).items() if k != "top30"},
            "per_volume_distinct_K2": {"median": statistics.median(k2vals), "max": max(k2vals), "max_volume": max(acc.per_volume_k2, key=acc.per_volume_k2.get), "min": min(k2vals)},
            "per_volume_pairs": {"median": statistics.median(pv), "max": max(pv)},
            "artifact": {"path": acc.path, "bytes": raw_bytes, "gzip_bytes": gz_bytes, "vocab_size": len(acc.vocab)},
            "head_body_mismatches": acc.head_mismatch,
        }
        if label in UNIONS:
            arm["rows_note"] = "rows = component rows summed (overlapping spans counted in both layers); rows_dedup_span = distinct (doc,s,e)"
            arm["rows_dedup_span"] = acc.rows_dedup_span
        if label == "marked":
            arm["typed_split"] = dict(acc.typed)
        result["arms"][label] = arm
    for label, (store, layer, expected) in ARMS.items():
        result["positive_controls"][label] = {"expected": expected, "measured": accs[label].rows, "ok": accs[label].rows == expected}
    result["positive_controls"]["marked_typed_split"] = {"expected": {"from": 140504, "to": 95247, "untyped": 9996}, "measured": dict(accs["marked"].typed)}
    result["elapsed_secs"] = round(time.time() - t0, 1)
    with open(os.path.join(OUT_DIR, "census.json"), "w", encoding="utf-8") as fh:
        json.dump(result, fh, indent=1, ensure_ascii=False)
    print(json.dumps(result["positive_controls"], indent=1))
    print("elapsed", result["elapsed_secs"])

# per-volume row count for the union accumulation
_orig_add = ArmAcc.add_volume
def _add_volume(self, volume, band, doc_rows, _):
    self.per_volume_rows_last = sum(len(v) for v in doc_rows.values())
    return _orig_add(self, volume, band, doc_rows, _)
ArmAcc.add_volume = _add_volume

if __name__ == "__main__":
    main()
