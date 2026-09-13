#!/usr/bin/env python3
"""Corpus-scale size of a verification queue fed by the three layers, at the (volume, document, K2) grain.
K2 copied verbatim from feasibility-2026-09-12/measure-census/census.py (one leading honorific, 29 tokens).
Positive control: marked / filtered control / filtered sweep / two unions must equal census.json's pairs.
Read-only over the stores. Stdlib only. Writes queue_pairs.json beside itself."""
import json, os, re, sys, time
from collections import Counter
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
import ner_store
HOME = os.path.expanduser("~")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "queue_pairs.json")
ARMS = {"marked": (os.path.join(HOME, "frus-ner-raw"), "marked"),
        "fc": (os.path.join(HOME, "frus-ner-raw-control-filtered"), "detected"),
        "fs": (os.path.join(HOME, "frus-ner-raw-filtered"), "detected")}
HONORIFICS = ["mr", "mrs", "miss", "dr", "sir", "hon", "general", "colonel", "captain", "major",
              "admiral", "señor", "monsieur", "herr", "mme", "messrs", "rev", "judge", "governor",
              "president", "minister", "count", "baron", "lord", "lady", "prince", "king", "queen", "m."]
_alts = [re.escape(h[:-1]) + r"\." if h.endswith(".") else re.escape(h) + r"\.?" for h in HONORIFICS]
HONORIFIC_RE = re.compile(r"^(?:" + "|".join(_alts) + r")\s+")
WS_RE = re.compile(r"\s+"); POSS_RE = re.compile(r"(?:’s|'s|’|')$")
def k2(surface):
    s = WS_RE.sub(" ", surface.casefold()).strip(); s = POSS_RE.sub("", s).strip()
    return HONORIFIC_RE.sub("", s, count=1).strip() or s
t0 = time.time()
vols = ner_store.scope_volumes(ARMS["marked"][0])
vols = [v if isinstance(v, str) else v.get("volume") or v.get("id") for v in vols]
tot = Counter(); byband = {}; docs_reached = Counter(); docs_only_fs = Counter()
for i, vol in enumerate(sorted(vols)):
    band = ner_store.band_of(vol) or "none"
    sets = {}
    for a, (store, layer) in ARMS.items():
        p = ner_store.layer_path(store, layer, vol)
        sets[a] = set() if p is None else {(r["d"], k2(r["n"])) for r in ner_store.read_jsonl_gz(p)}
    m, c, s = sets["marked"], sets["fc"], sets["fs"]
    mc = m | c; three = mc | s; sonly = s - mc; ms = m | s; cs_int_keys = c & s
    row = {"marked": len(m), "fc": len(c), "fs": len(s), "marked|fc": len(mc), "marked|fs": len(ms),
           "three_way": len(three), "fs_only_increment": len(sonly), "fc&fs_same_key": len(cs_int_keys)}
    b = byband.setdefault(band, Counter())
    for k, v in row.items(): tot[k] += v; b[k] += v
    d_mc = {d for d, _ in mc}; d_three = {d for d, _ in three}
    docs_reached["marked|fc"] += len(d_mc); docs_reached["three_way"] += len(d_three)
    docs_only_fs[band] += len(d_three - d_mc)
out = {"volumes": len(vols), "totals": dict(tot), "by_band": {k: dict(v) for k, v in sorted(byband.items())},
       "documents_reached": dict(docs_reached), "documents_reached_only_through_fs_by_band": dict(docs_only_fs),
       "positive_control_expected": {"marked": 223505, "fc": 732022, "fs": 1579296, "marked|fc": 864469, "marked|fs": 1596691},
       "secs": round(time.time() - t0, 1)}
out["positive_control_pass"] = all(out["totals"][k] == v for k, v in out["positive_control_expected"].items())
json.dump(out, open(OUT, "w"), indent=1); print(json.dumps(out, indent=1))
