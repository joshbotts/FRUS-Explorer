#!/usr/bin/env python3
"""INFERRED per-run cost of pre-annotating eval rows (role 6), using llm-pass/program-fit/pilot_cost.py's own formulas
and constants (INSTR 1500, HEADER 60 tokens; chars/token 4.652 low-cost end / 3.0 high-cost end; thinking allowance
4,000 tokens/request + 1x document tokens for S1, flat 6,000 per identity row for S2; standard pricing, halve for batch).
New volumes are INFERRED: 500 location-precision rows scaled from the 300-row eval's measured doc chars and POCOM blocks;
250 fresh NER documents at the corpus mean document length 3,439.42 chars (llm-pass analysis.json, TEI-rule scope)."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
PC = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/llm-pass/program-fit"
s1 = json.load(open(PC + "/stage1_sizing.json")); s2 = json.load(open(PC + "/stage2_sizing.json"))
PRICE = {"sonnet-5": (2.0, 10.0), "opus-5": (5.0, 25.0)}; CPT = {"low": 4.652, "high": 3.0}
out = {}
for end, cpt in CPT.items():
    # 250 fresh documents, S1-c shape (adjudicate a candidate list)
    docs = 250; chars = docs * 3439.42; gold_density = s1["gold_mentions"] / s1["r0_chars_total"]
    cand = s1["three_way_union_distinct_offsets_total"] / s1["r0_chars_total"] * chars
    dt = chars / cpt
    fresh = dict(inp=docs * 1560 + dt + cand * 50, out=cand * 20 + docs * 4000 + dt)
    # 500 location rows, S2 shape
    f = 500 / s2["rows"]
    loc = dict(inp=500 * 1560 + s2["doc_chars"]["total_capped_20000"] * f / cpt + (s2["pocom_appointments_per_row"]["total"] * 30 + s2["pocom_candidates_per_row"]["total"] * 20) * f,
               out=500 * 6200)
    for name, t in (("250 fresh NER documents (S1-c shape)", fresh), ("500 pre-1900 location/identity rows (S2 shape)", loc)):
        for m, (pi, po) in PRICE.items():
            usd = (t["inp"] * pi + t["out"] * po) / 1e6
            out.setdefault(name, {}).setdefault(m, {})[end] = {"usd_per_run_standard": round(usd, 2), "usd_per_run_batch": round(usd / 2, 2),
                                                               "input_tok": round(t["inp"]), "output_tok_ceiling": round(t["out"])}
json.dump(out, open(os.path.join(HERE, "r6-preannotate.json"), "w"), indent=1); print(json.dumps(out, indent=1))
