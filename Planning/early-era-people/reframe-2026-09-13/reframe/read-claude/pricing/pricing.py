#!/usr/bin/env python3
"""INFERRED prices for the reframed Claude roles, at the UNIT PRICES AND MECHANICS OF llm-pass/cost-scale/cost_model.py
(copied, not imported: importing it would rewrite that directory's costs.json). cost_model.py labels its $/MTok
"DOCUMENTED" but records NO pricing date and NO source URL; the file is dated 2026-09-13 07:31 on disk.
Copied constants: PRICE $/MTok in/out haiku-4.5 1/5, sonnet-5 2/10, opus-5 5/25; batch x0.5; cache read x0.1 input,
cache write x1.25 input, one refresh write per 1,000 requests; minimum cacheable prefix haiku 4096 / sonnet 1024 /
opus 512; cached instruction prefix 1,100 / 3,000 / 6,000 tokens; cache-hit share 1.0 / 0.9 / 0.5; tokenizer
multiplier vs Qwen3's 4.6442 chars/token (MEASURED fit) haiku 1.00/1.12/1.25, sonnet 1.30/1.46/1.63, opus 1.00/1.31/1.69;
thinking tokens = a*visible_output + b*requests, B (decision) low (0.1,50) high (1.0,500), C (identity/synthesis)
low (0.3,100) high (2.0,1500); +30 tokens per request. Scenario index 0 low / 1 central / 2 high.
Every row volume below is MEASURED (file named in `basis`) unless marked INFERRED."""
import json, math, os
HERE = os.path.dirname(os.path.abspath(__file__))
QWEN_CPT = 4.6442
MULT = {"haiku-4.5": (1.00, 1.12, 1.25), "sonnet-5": (1.30, 1.46, 1.63), "opus-5": (1.00, 1.31, 1.69)}
PRICE = {"haiku-4.5": (1.0, 5.0), "sonnet-5": (2.0, 10.0), "opus-5": (5.0, 25.0)}
MINCACHE = {"haiku-4.5": 4096, "sonnet-5": 1024, "opus-5": 512}
PREFIX = (1100, 3000, 6000); CACHE_HIT = (1.0, 0.9, 0.5)
THINK = {"B": {"low": (0.1, 50), "high": (1.0, 500)}, "C": {"low": (0.3, 100), "high": (2.0, 1500)}}

def price(model, i, requests, in_chars, out_tok, shape, effort, batch=True, cached=True):
    pin, pout = PRICE[model]; cpt = QWEN_CPT / MULT[model][i]
    var_in = in_chars / cpt + requests * 30
    pref = PREFIX[i]; a, b = THINK[shape][effort]
    if model == "haiku-4.5" and effort == "low": a, b = 0.0, 0
    think = a * out_tok + b * requests
    can = cached and pref >= MINCACHE[model]; hit = CACHE_HIT[i] if can else 0.0
    d = (var_in * pin + requests * pref * (1 - hit) * pin + requests * pref * hit * pin * 0.1
         + (math.ceil(requests / 1000) * pref * pin * 1.25 if can else 0) + (out_tok + think) * pout) / 1e6
    return (d * 0.5 if batch else d), (var_in + requests * pref) / 1e6, out_tok / 1e6, think / 1e6

D = json.load(open(os.path.join(HERE, "..", "disagreement", "disagreement.json")))["corpus"]["all"]
CR = {r["arm"] + "|" + r["band"]: r for r in json.load(open(os.path.join(HERE, "..", "chapter-rule-after", "summary.json")))}
SY = json.load(open(os.path.join(HERE, "..", "synthesis-size", "synthesis-size.json")))
TARGET = (40000, 20000, None)   # packing: chars per request (None = one request per document), as cost_model's A/B shapes

def decision_job(name, keys, docs, win_first, win_all, surf_chars, accept, basis):
    rows = []
    for i in range(3):
        in_chars = [win_first, win_first, win_all][i] + surf_chars + keys * [8, 12, 20][i] + docs * 60
        req = docs if TARGET[i] is None else max(1, math.ceil(in_chars / TARGET[i]))
        acc_tok, rej_tok = [(9, 5), (12, 7), (20, 10)][i]
        out = keys * (accept[i] * acc_tok + (1 - accept[i]) * rej_tok) + docs * 10
        rows.append(dict(requests=req, in_chars=in_chars, out_tok=out))
    return dict(role=name, basis=basis, scen=rows)

jobs = []
jobs.append(decision_job("R2a verify DISAGREEMENT set only (unmarked FS-only U FC-only), +/-200-char merged windows",
    D["disagreement"]["doc_surface_keys"], D["disagreement"]["documents"], D["disagreement"]["window_chars_first_per_key"],
    D["disagreement"]["window_chars_all_spans"], D["disagreement"]["surface_chars"], (0.22, 0.22, 0.35),
    "disagreement/disagreement.json corpus.all.disagreement; accept share 0.22 = 96 of 445 gold-doc disagreement spans a perfect verifier keeps (POST-HOC)"))
jobs.append(decision_job("R2b verify AGREEMENT arm only (unmarked FS spans overlapping FC) - the precision role",
    D["agree_S"]["doc_surface_keys"], D["agree_S"]["documents"], D["agree_S"]["window_chars_first_per_key"],
    D["agree_S"]["window_chars_all_spans"], D["agree_S"]["surface_chars"], (0.85, 0.85, 0.95),
    "disagreement/disagreement.json corpus.all.agree_S; accept share INFERRED from b2 presence P 0.898"))
jobs.append(decision_job("R2c recall-first review queue = whole unmarked pool (FC U FS), windows",
    D["pool"]["doc_surface_keys"], D["pool"]["documents"], D["pool"]["window_chars_first_per_key"],
    D["pool"]["window_chars_all_spans"], D["pool"]["surface_chars"], (0.45, 0.45, 0.6),
    "disagreement/disagreement.json corpus.all.pool; accept INFERRED from union presence P 0.491"))
# R3: Source Explorer x POCOM adjudication rows (post-#1292 arm B, 1861-1905 volumes)
b, b2 = CR["B|1861-1899"], CR["B|1900-1905"]
r3_rows = b["one_contradicted"] + b2["one_contradicted"] + b["several_to_one_other"] + b2["several_to_one_other"] + b["several_to_one_by_secretary_over_same_surname_assistant"]
def row_job(name, rows, per_row_chars, rows_per_req, out_per_row, basis):
    sc = []
    for i in range(3):
        req = math.ceil(rows / rows_per_req[i])
        sc.append(dict(requests=req, in_chars=rows * per_row_chars[i], out_tok=rows * out_per_row[i] + req * 10))
    return dict(role=name, basis=basis, scen=sc)
jobs.append(row_job("R3 adjudicate SE x POCOM: contradicted + location-narrowed + Seward-convention rows", r3_rows,
    (700, 1200, 2500), (25, 10, 5), (25, 40, 80),
    "chapter-rule-after/summary.json arm B (post-#1292): %d rows; per-row chars INFERRED = head+dateline (106 mean, app view) + chapter path + 1-5 POCOM careers (p90 188 / p99 424 chars) + opening/closing text for signatures" % r3_rows))
# R4: identity proposals for correspondents with no unique live POCOM candidate (volume x surface rows, marked layer)
pc = {"rows": 29949, "unresolved": 21653 + 1035, "snip_cap3": 58240, "desc": 1511268}
per_row = [60 + pc["snip_cap3"] / pc["rows"] * s + pc["desc"] / pc["rows"] for s in (260, 320, 420)]
jobs.append(row_job("R4 propose identities for unresolved marked correspondents (volume x surface rows with 0 or >1 live POCOM candidate)",
    pc["unresolved"], per_row, (50, 25, 10), (15, 25, 45),
    "llm-pass/cost-scale/pocom-payload-v2.json marked rows_0_live 21,653 + rows_several_live 1,035; per-row chars = cost_model C formula"))
# R5: synthesis per chapter
app = SY["app_view"]; tei = SY["tei_rule"]
syn_in = app["header_plus_dateline_chars_total"] + app["documents_under_sections"] * 8 + pc["desc"] + app["sections_listing_documents"] * 100
corr = tei["distinct_fromto_keys_per_volume_sum"]
sc = []
for i, (per_chap, per_corr, mult) in enumerate(((150, 60, 1.0), (150, 80, 2.0), (300, 150, 3.0))):
    sc.append(dict(requests=app["sections_listing_documents"], in_chars=syn_in, out_tok=app["sections_listing_documents"] * per_chap + corr * mult * per_corr))
jobs.append(dict(role="R5 synthesis: per-chapter correspondents guide (12,087 sections)", scen=sc,
    basis="synthesis-size/synthesis-size.json: app-view sections %d, header+dateline chars %d (+8 chars/doc id, +100 chars/section roll pointer, + marked POCOM careers 1,511,268 chars); OUTPUT INFERRED: per-chapter 150-300 tok + 60-150 tok per correspondent x (1-3)x the TEI-rule per-volume distinct from/to key sum %d (per-chapter distinct count NOT measured)" % (app["sections_listing_documents"], app["header_plus_dateline_chars_total"], corr)))
sc = [dict(s) for s in sc]
for s in sc: s["requests"] = 267
jobs.append(dict(role="R5' synthesis: per-volume guide (267 requests, same facts)", scen=sc, basis="as R5, one request per volume"))
# R7: rule / gazetteer drafting
jobs.append(dict(role="R7a draft filter rules from M2a errors.json (in-sample; x3 reps)", basis="errors.json 738,010 bytes (MEASURED); output 20k tok/rep INFERRED",
    scen=[dict(requests=4 * 3, in_chars=738010 * 3, out_tok=20000 * 3)] * 3))
jobs.append(dict(role="R7b classify top-20,000 sweep surfaces by frequency, no gold, no context (x3 reps)", basis="INFERRED 25 chars/surface, 1,000 surfaces/request, 6 tok/decision",
    scen=[dict(requests=20 * 3, in_chars=20000 * 25 * 3, out_tok=20000 * 6 * 3)] * 3))

out = {"method": __doc__, "r3_rows": r3_rows, "r4_rows": pc["unresolved"], "synthesis_input_chars": syn_in, "jobs": []}
for j in jobs:
    res = {}
    for m in PRICE:
        shape = "B" if j["role"].startswith("R2") or j["role"].startswith("R7b") else "C"
        lo = price(m, 0, j["scen"][0]["requests"], j["scen"][0]["in_chars"], j["scen"][0]["out_tok"], shape, "low")
        cl = price(m, 1, j["scen"][1]["requests"], j["scen"][1]["in_chars"], j["scen"][1]["out_tok"], shape, "low")
        ch = price(m, 1, j["scen"][1]["requests"], j["scen"][1]["in_chars"], j["scen"][1]["out_tok"], shape, "high")
        hh = price(m, 2, j["scen"][2]["requests"], j["scen"][2]["in_chars"], j["scen"][2]["out_tok"], shape, "high")
        std = price(m, 1, j["scen"][1]["requests"], j["scen"][1]["in_chars"], j["scen"][1]["out_tok"], shape, "low", batch=False, cached=False)
        res[m] = {"batch_cached_low_scen_low_effort": round(lo[0], 1), "batch_cached_central_low_effort": round(cl[0], 1),
                  "batch_cached_central_high_effort": round(ch[0], 1), "batch_cached_high_scen_high_effort": round(hh[0], 1),
                  "standard_uncached_central_low_effort": round(std[0], 1),
                  "central_tokens_M_in_out_think_low": [round(cl[1], 2), round(cl[2], 2), round(cl[3], 2)]}
    out["jobs"].append(dict(role=j["role"], basis=j["basis"], shape=shape, requests=[s["requests"] for s in j["scen"]],
                            input_chars=[s["in_chars"] for s in j["scen"]], prices=res))
json.dump(out, open(os.path.join(HERE, "pricing.json"), "w"), indent=1)
for j in out["jobs"]:
    print("\n##", j["role"]); print("   requests", j["requests"], "input chars", [int(x) for x in j["input_chars"]])
    for m, p in j["prices"].items():
        print("   %-10s lo/low %8.1f | cen/low %8.1f | cen/high %8.1f | hi/high %8.1f | std-uncached cen/low %8.1f | tok M %s" % (m,
              p["batch_cached_low_scen_low_effort"], p["batch_cached_central_low_effort"], p["batch_cached_central_high_effort"],
              p["batch_cached_high_scen_high_effort"], p["standard_uncached_central_low_effort"], p["central_tokens_M_in_out_think_low"]))
