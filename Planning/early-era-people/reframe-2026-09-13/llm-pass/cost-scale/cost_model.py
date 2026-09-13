#!/usr/bin/env python3
"""Cost model for three Claude pass shapes over the 267-volume scope. Every input is read from
analysis.json / pocom-payload(-v2).json / gold-density.json / bytes.json in this directory, or is a
named assumption below. No API is called. Writes costs.json + costs.md."""
import json, os, math, csv, collections
HERE = os.path.dirname(os.path.abspath(__file__))
J = lambda f: json.load(open(os.path.join(HERE, f)))
AN, PC, PC2, GD, BY = J("analysis.json"), J("pocom-payload.json"), J("pocom-payload-v2.json"), J("gold-density.json"), J("bytes.json")
HAIKU_MIN = int(os.environ.get("HAIKU_MIN", "4096"))

QWEN_CPT = AN["anchor_regression"]["chars_per_token"]          # 4.6442 text chars / Qwen3 token (MEASURED fit)
QWEN_TOK_PER_STRING = AN["completion_tokens_per_returned_string"]  # 8.123 (MEASURED)
# tokenizer multipliers vs Qwen3 (INFERRED): old Claude tokenizer 1.00/1.12/1.25 x Qwen3;
# Sonnet 5 = 1.30 x that (DOCUMENTED ~30% over Sonnet 4.6); Opus 5 = 1.00-1.35 x old (DOCUMENTED range)
MULT = {"haiku-4.5": (1.00, 1.12, 1.25), "sonnet-5": (1.30, 1.46, 1.63), "opus-5": (1.00, 1.31, 1.69)}
PRICE = {"haiku-4.5": (1.0, 5.0), "sonnet-5": (2.0, 10.0), "opus-5": (5.0, 25.0)}   # DOCUMENTED $/MTok
MINCACHE = {"haiku-4.5": HAIKU_MIN, "sonnet-5": 1024, "opus-5": 512}
PREFIX = (1100, 3000, 6000)          # Claude tokens of cached instructions (INFERRED; M2a-INSTRUCTIONS.md is 2,501 chars)
CACHE_HIT = (1.0, 0.9, 0.5)          # share of requests that read the prefix from cache (INFERRED; best-effort in batches)
# thinking (INFERRED): tokens = a * visible_output + b per request
THINK = {"A": {"low": (0.1, 50), "high": (1.0, 500)}, "B": {"low": (0.1, 50), "high": (1.0, 500)},
         "C": {"low": (0.3, 100), "high": (2.0, 1500)}}
BATCH_REQ, BATCH_BYTES = 100000, 256 * 1024 * 1024

T = AN["anchor_totals"]; P = AN["packing"]
M_CORPUS_CHARS = AN["doc_chars"]["sum"]
gold_per_k = GD["gold_mentions_per_1k_chars"]
# mention count scenarios for Shape A output (INFERRED from MEASURED densities)
sweep_ratio = (2597043 / M_CORPUS_CHARS * 1000) / GD["on_gold_docs_per_1k_chars"]["fsweep"]
MENTIONS = (round(gold_per_k * sweep_ratio * M_CORPUS_CHARS / 1000), round(gold_per_k * M_CORPUS_CHARS / 1000), T["mentions"])

def shape_inputs(i, model):
    """Per scenario i (0 low,1 central,2 high): dict per shape of requests, text_tokens, var_out tokens, bytes."""
    mult = MULT[model][i]; cpt = QWEN_CPT / mult
    out = {}
    # ---- A: packing central = 20k target / 40k cap; low = 40k/40k; high = per-document (40k cap)
    pk = [P["target40000_cap40000_ov2000"], P["target20000_cap40000_ov2000"], P["target0_cap40000_ov2000"]][i]
    reqs = pk["requests"]; billed = pk["billed_chars"]; pieces = 197534 + 2650 - 1021
    tok_per_mention = [QWEN_TOK_PER_STRING * mult, QWEN_TOK_PER_STRING * mult + 4, (QWEN_TOK_PER_STRING + 60 / QWEN_CPT) * mult][i]
    out["A"] = dict(requests=reqs, var_in=billed / cpt + pieces * 15 + reqs * 30,
                    vis_out=MENTIONS[i] * tok_per_mention + pieces * 20,
                    body_bytes=BY["json_ascii_escaped_bytes"] * billed / M_CORPUS_CHARS + reqs * 600,
                    notes="packing %s; mentions %d; %.1f tok/mention; cpt %.3f" % (["40k/40k", "20k/40k", "per-doc"][i], MENTIONS[i], tok_per_mention, cpt))
    # ---- B: text as A + candidate list; decisions on (doc,surface) [low] or exact span [central/high]
    ud = AN["per_doc_union_surfaces"]["sum"]; us = AN["per_doc_union_exact"]["sum"]
    cand_chars = [AN["per_doc_union_surface_chars"]["sum"] + ud * 8, AN["per_doc_union_span_chars"]["sum"] + us * 12, AN["per_doc_union_span_chars"]["sum"] + us * 20][i]
    ncand = [ud, us, us][i]
    accept = [0.49, 0.49, 0.60][i]    # relaxed union P (DOCUMENTED 0.491 presence) ; high allows more accepts
    rej_tok, acc_tok = [(5, 9), (7, 12), (10, 20)][i]
    out["B"] = dict(requests=reqs, var_in=billed / cpt + cand_chars / cpt + pieces * 15 + reqs * 30,
                    vis_out=ncand * (accept * acc_tok + (1 - accept) * rej_tok) * mult / MULT[model][1] + pieces * 20,
                    body_bytes=BY["json_ascii_escaped_bytes"] * billed / M_CORPUS_CHARS + cand_chars * 1.05 + reqs * 600,
                    notes="candidates %d (%s); candidate chars %d" % (ncand, ["doc x surface", "exact span", "exact span + arm flags"][i], cand_chars))
    # ---- C: identity rows
    for label, rows_census, pay, liveonly in (("C_marked_all", 30327, PC["marked"], False), ("C_union_all", 340614, PC["marked_union_filtered_control"], False),
                                             ("C_marked_live", None, PC2["marked"], True), ("C_union_live", None, PC2["marked_union_filtered_control"], True)):
        snip_chars = [260, 320, 420][i]; header = 60
        if liveonly:
            lr = pay["live_rows"]; rows = lr["rows"]
            per_row = header + lr["snippets_cap3"] / rows * snip_chars + lr["desc_chars_in_window"] / rows
        else:
            rows = rows_census
            per_row = header + pay["snippets_cap3"] / pay["rows"] * snip_chars + pay["desc_chars_in_window_appts"]["sum"] / pay["rows"]
        k = [50, 25, 10][i]; creq = math.ceil(rows / k)
        row_out = [15, 25, 45][i]
        out[label] = dict(requests=creq, var_in=rows * per_row / cpt + creq * 30, vis_out=rows * row_out + creq * 10,
                          body_bytes=rows * per_row * 1.02 + creq * 600, notes="rows %d; %.0f chars/row; %d rows/request" % (rows, per_row, k))
    return out

def price(model, sh, d, effort, batch, cached, i):
    pin, pout = PRICE[model]; mult = MULT[model][i]
    pref = PREFIX[i]
    a, b = THINK[sh[0]][effort]
    if model == "haiku-4.5" and effort == "low":
        a, b = 0.0, 0                   # Haiku 4.5: thinking off unless enabled (DOCUMENTED: off by default on pre-4.7 models)
    think = a * d["vis_out"] + b * d["requests"]
    can_cache = cached and pref >= MINCACHE[model]
    hit = CACHE_HIT[i] if can_cache else 0.0
    pref_full = d["requests"] * pref * (1 - hit)
    pref_read = d["requests"] * pref * hit
    writes = math.ceil(d["requests"] / 1000) * pref if can_cache else 0   # a refresh write every ~1,000 requests (INFERRED)
    dollars = (d["var_in"] * pin + pref_full * pin + pref_read * pin * 0.1 + writes * pin * 1.25 + (d["vis_out"] + think) * pout) / 1e6
    if batch: dollars *= 0.5
    return dollars, d["var_in"] + d["requests"] * pref, d["vis_out"], think, can_cache

res = {"inputs": {"qwen_chars_per_token_text": QWEN_CPT, "qwen_overhead_tokens_per_chunk": AN["anchor_regression"]["overhead_tokens_per_chunk"],
                  "mentions_scenarios": MENTIONS, "sweep_gold_ratio": sweep_ratio, "multipliers": MULT, "prefix_tokens": PREFIX, "cache_hit": CACHE_HIT,
                  "think": THINK, "haiku_min_cache": HAIKU_MIN}, "rows": []}
for model in PRICE:
    S3 = [shape_inputs(i, model) for i in range(3)]
    for sh in S3[0]:
        for effort in ("low", "high"):
            for batch in (False, True):
                for cached in (False, True):
                    vals = [price(model, sh, S3[i][sh], effort, batch, cached, i) for i in range(3)]
                    res["rows"].append(dict(model=model, shape=sh, effort=effort, batch=batch, cached=cached,
                        dollars=[round(v[0]) for v in vals], input_tok_M=[round(v[1] / 1e6, 1) for v in vals],
                        output_tok_M=[round(v[2] / 1e6, 1) for v in vals], thinking_tok_M=[round(v[3] / 1e6, 1) for v in vals],
                        cache_eligible=[v[4] for v in vals]))
        for sh in S3[0]:
            res.setdefault("volumes", {}).setdefault(model, {})[sh] = [dict(requests=S3[i][sh]["requests"], batches=max(math.ceil(S3[i][sh]["requests"] / BATCH_REQ),
                     math.ceil((S3[i][sh]["body_bytes"] + S3[i][sh]["requests"] * PREFIX[i] * (QWEN_CPT / MULT[model][i]) * 1.01) / BATCH_BYTES)),
                     body_MB=round((S3[i][sh]["body_bytes"] + S3[i][sh]["requests"] * PREFIX[i] * (QWEN_CPT / MULT[model][i]) * 1.01) / 1e6), notes=S3[i][sh]["notes"]) for i in range(3)]
# per-volume Shape A cost spread, Sonnet 5 batch cached low effort central
rows = list(csv.DictReader(open(os.path.join(HERE, "docs.tsv")), delimiter="\t"))
per = collections.Counter()
for r in rows: per[r["vol"]] += int(r["chars"])
cptc = QWEN_CPT / MULT["sonnet-5"][1]
tot_central = [x for x in res["rows"] if x["model"] == "sonnet-5" and x["shape"] == "A" and x["effort"] == "low" and x["batch"] and x["cached"]][0]["dollars"][1]
vc = sorted((tot_central * c / M_CORPUS_CHARS, v) for v, c in per.items())
res["per_volume_shareA_sonnet5_batch_cached_low_central"] = {"min": [round(vc[0][0], 2), vc[0][1]], "p50": round(vc[len(vc) // 2][0], 2), "max": [round(vc[-1][0], 2), vc[-1][1]], "top3": [(v, round(d, 2)) for d, v in vc[-3:]]}
json.dump(res, open(os.path.join(HERE, "costs.json"), "w"), indent=1)
with open(os.path.join(HERE, "costs.md"), "w") as f:
    f.write("| model | shape | effort | batch | cached | $ low / central / high | input MTok | visible out MTok | thinking MTok |\n|---|---|---|---|---|---|---|---|---|\n")
    for x in res["rows"]:
        f.write("| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n" % (x["model"], x["shape"], x["effort"], "Y" if x["batch"] else "N", ("Y" if x["cached"] else "N") + ("" if all(x["cache_eligible"]) or not x["cached"] else "*"),
                " / ".join("{:,}".format(d) for d in x["dollars"]), " / ".join(map(str, x["input_tok_M"])), " / ".join(map(str, x["output_tok_M"])), " / ".join(map(str, x["thinking_tok_M"]))))
print(json.dumps(res["inputs"], indent=1)); print(json.dumps(res["volumes"]["sonnet-5"], indent=1)); print(res["per_volume_shareA_sonnet5_batch_cached_low_central"])
