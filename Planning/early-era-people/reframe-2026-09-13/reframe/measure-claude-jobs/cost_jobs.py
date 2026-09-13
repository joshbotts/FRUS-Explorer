#!/usr/bin/env python3
"""measure-claude-jobs/cost_jobs.py — prices the reframed-#234 Claude jobs A-E from the MEASURED volumes in this
directory (pools.json, se-pocom-cases-*.json, volume-guides.json) and the recorded unit prices and treatments of
llm-pass/cost-scale/cost_model.py. Every dollar and every token figure here is INFERRED (characters -> tokens through
cost_model.py's MEASURED Qwen3 chars/token and its INFERRED per-model multipliers). No API, no tokenizer endpoint.

cost_model.py is READ, never executed or imported (executing it rewrites its own costs.json): PRICE, MULT, MINCACHE,
PREFIX, CACHE_HIT and THINK are pulled from its source by AST; the in-function constants used below (shape B's verdict
token pairs and accept rates, shape C's rows-per-request and row output) are asserted to be present verbatim.
Local-model time and electricity are INFERRED from the sweep's DOCUMENTED aggregate throughput (NER-RUNBOOK §4.8.3).
Writes cost-jobs.json + cost-jobs.md here.
"""
import sys
sys.dont_write_bytecode = True
import os, json, ast, math

HERE = os.path.dirname(os.path.abspath(__file__))
SP = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad"
CM = SP + "/llm-pass/cost-scale/cost_model.py"
SRC = open(CM).read()
TREE = ast.parse(SRC)


def node(name):
    for n in TREE.body:
        if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == name for t in n.targets):
            return n.value
    raise KeyError(name)


def ev(n):
    if isinstance(n, ast.Name) and n.id == "HAIKU_MIN":
        return int(os.environ.get("HAIKU_MIN", "4096"))
    if isinstance(n, ast.Dict):
        return {ev(k): ev(v) for k, v in zip(n.keys, n.values)}
    if isinstance(n, ast.Tuple):
        return tuple(ev(e) for e in n.elts)
    return ast.literal_eval(n)


PRICE, MULT, MINCACHE, PREFIX, CACHE_HIT, THINK = (ev(node(k)) for k in ("PRICE", "MULT", "MINCACHE", "PREFIX", "CACHE_HIT", "THINK"))
for frag in ("rej_tok, acc_tok = [(5, 9), (7, 12), (10, 20)][i]", "accept = [0.49, 0.49, 0.60][i]", "k = [50, 25, 10][i]",
             "row_out = [15, 25, 45][i]", "BATCH_REQ, BATCH_BYTES = 100000, 256 * 1024 * 1024", "if batch: dollars *= 0.5",
             "pref_read * pin * 0.1 + writes * pin * 1.25", "reqs * 30", "pieces * 20", "creq * 10"):
    assert frag in SRC, "cost_model.py changed: " + frag
REJ_ACC = [(5, 9), (7, 12), (10, 20)]
ACCEPT_B = [0.49, 0.49, 0.60]
C_K, C_ROW_OUT = [50, 25, 10], [15, 25, 45]
BATCH_REQ, BATCH_BYTES = 100000, 256 * 1024 * 1024
AN = json.load(open(SP + "/llm-pass/cost-scale/analysis.json"))
BY = json.load(open(SP + "/llm-pass/cost-scale/bytes.json"))
QWEN_CPT = AN["anchor_regression"]["chars_per_token"]
QWEN_OVERHEAD = AN["anchor_regression"]["overhead_tokens_per_chunk"]
JSON_BYTES_PER_CHAR = BY["json_ascii_escaped_bytes"] / BY["chars"]

PO = json.load(open(os.path.join(HERE, "pools.json")))
CPW = PO["chars_per_whitespace_word"]
VG = json.load(open(os.path.join(HERE, "volume-guides.json")))
SE = {lab: json.load(open(os.path.join(HERE, "se-pocom-cases-%s.json" % lab))) for lab in ("pre1292", "post1292")}
SUMM = {(s["arm"], s["band"]): s for s in json.load(open(SP + "/chapter-context/coverage/summary.json"))}

# ---- the sweep's DOCUMENTED aggregate (NER-RUNBOOK §4.8.3), wall clock at WORKERS=4 on the Mac Studio
SWEEP_S, SWEEP_CHUNKS, SWEEP_PT, SWEEP_CT = 997807.6, 330979, 220645005, 21131474
assert AN["anchor_totals"]["prompt_tokens"] == SWEEP_PT and AN["anchor_totals"]["completion_tokens"] == SWEEP_CT
RATIO = 75 / 6.2      # DOCUMENTED §4.8 decomposition: prefill ~75 tok/s, decode ~6.2 tok/s (14B no-think pilot) -> per-token cost ratio
T_UNIFORM = SWEEP_S / (SWEEP_PT + SWEEP_CT)
T_PREFILL = SWEEP_S / (SWEEP_PT + RATIO * SWEEP_CT)
T_DECODE = RATIO * T_PREFILL
WATTS = (90, 120)     # DOCUMENTED assumption recorded in llm-pass/cost-scale/side.json
USD_KWH = (0.15, 0.25)
BIGGER = (1.9, 2.2)   # INFERRED: 27-31B dense judge vs 14B, time scaled by parameter ratio (27/14, 31/14)


# ------------------------------------------------------------------ job shapes -> per-scenario volumes
def span_job(P, accept):
    """A / B: verify candidates. i=0 low: one verdict per (document, surface key), documents packed to 40k chars;
    i=1 central: one verdict per span, packed to 20k chars; i=2 high: one verdict per span, each with its OWN unmerged
    window, one request per document."""
    out = []
    for i in range(3):
        dec = P["doc_keys"] if i == 0 else P["spans"]
        listing = P["listing_chars"] * (P["doc_keys"] / P["spans"] if i == 0 else 1)
        ctx = P["window_chars_merged_per_doc"] if i < 2 else P["window_chars_per_span"]
        req = [P["req_pack40000"], P["req_pack20000"], P["docs"]][i]
        out.append(dict(kind="span", requests=req, in_chars=ctx + listing, decisions=dec, accept=accept[i] if isinstance(accept, list) else accept, think="B"))
    return out


def case_job(rows, chars_per_row):
    """C: adjudicate cases, k rows per request (50 / 25 / 10), row output 15 / 25 / 45 tokens (cost_model.py shape C)."""
    return [dict(kind="case", requests=math.ceil(rows / C_K[i]), in_chars=rows * chars_per_row[i], rows=rows, think="C") for i in range(3)]


def synth_job(requests, in_chars, words):
    return [dict(kind="synth", requests=requests[i], in_chars=in_chars[i], words=words[i], think="C") for i in range(3)]


def tokens(d, model, i):
    mult = MULT[model][i]
    cpt = QWEN_CPT / mult
    var_in = d["in_chars"] / cpt + d["requests"] * 30
    if d["kind"] == "span":
        rej, acc = REJ_ACC[i]
        vis = d["decisions"] * (d["accept"] * acc + (1 - d["accept"]) * rej) * mult / MULT[model][1] + d["requests"] * 20
    elif d["kind"] == "case":
        vis = d["rows"] * C_ROW_OUT[i] + d["requests"] * 10
    else:
        vis = d["requests"] * d["words"] * CPW / cpt
    return var_in, vis, cpt


def price(model, d, effort, batch, cached, i):
    """cost_model.py's price(), line for line, on this job's volumes."""
    pin, pout = PRICE[model]
    pref = PREFIX[i]
    var_in, vis, cpt = tokens(d, model, i)
    a, b = THINK[d["think"]][effort]
    if model == "haiku-4.5" and effort == "low":
        a, b = 0.0, 0
    think = a * vis + b * d["requests"]
    can_cache = cached and pref >= MINCACHE[model]
    hit = CACHE_HIT[i] if can_cache else 0.0
    pref_full = d["requests"] * pref * (1 - hit)
    pref_read = d["requests"] * pref * hit
    writes = math.ceil(d["requests"] / 1000) * pref if can_cache else 0
    dollars = (var_in * pin + pref_full * pin + pref_read * pin * 0.1 + writes * pin * 1.25 + (vis + think) * pout) / 1e6
    if batch:
        dollars *= 0.5
    body = d["in_chars"] * JSON_BYTES_PER_CHAR + d["requests"] * 600 + d["requests"] * pref * cpt * 1.01
    batches = max(math.ceil(d["requests"] / BATCH_REQ), math.ceil(body / BATCH_BYTES))
    return dollars, var_in + d["requests"] * pref, vis, think, batches, body


def local(d, i, think_effort=None):
    """Qwen-token volumes for a local run; prefix re-prefilled per request (0 at i=0: KV reuse assumed)."""
    q_in = d["in_chars"] / QWEN_CPT + d["requests"] * (QWEN_OVERHEAD + (0 if i == 0 else PREFIX[i]))
    _, vis, _ = tokens(d, "haiku-4.5", i)
    q_out = vis / MULT["haiku-4.5"][i]
    if think_effort:
        a, b = THINK[d["think"]][think_effort]
        q_out += a * q_out + b * d["requests"]
    secs = sorted([(q_in + q_out) * T_UNIFORM, q_in * T_PREFILL + q_out * T_DECODE])
    return q_in, q_out, secs


def job_table(name, scen, note):
    row = {"job": name, "note": note, "scenarios": [{k: v for k, v in d.items()} for d in scen], "models": {}, "local": {}}
    for model in PRICE:
        M = {}
        for effort in ("low", "high"):
            for batch in (False, True):
                for cached in (False, True):
                    vals = [price(model, scen[i], effort, batch, cached, i) for i in range(3)]
                    M["%s|%s|%s" % (effort, "batch" if batch else "standard", "cached" if cached else "uncached")] = {
                        "usd": [round(v[0], 2) for v in vals], "input_MTok": [round(v[1] / 1e6, 3) for v in vals],
                        "visible_output_MTok": [round(v[2] / 1e6, 3) for v in vals], "thinking_MTok": [round(v[3] / 1e6, 3) for v in vals],
                        "batches": [v[4] for v in vals], "body_MB": [round(v[5] / 1e6, 1) for v in vals]}
        row["models"][model] = M
    for mode, te in (("no-think 14B", None), ("thinking 14B, low allowance", "low"), ("thinking 14B, high allowance", "high")):
        vals = [local(scen[i], i, te) for i in range(3)]
        lo_h = min(v[2][0] for v in vals) / 3600
        hi_h = max(v[2][1] for v in vals) / 3600
        cen = vals[1][2]
        row["local"][mode] = {"qwen_in_MTok": [round(v[0] / 1e6, 3) for v in vals], "qwen_out_MTok": [round(v[1] / 1e6, 3) for v in vals],
                              "hours_central_scenario_two_time_models": [round(cen[0] / 3600, 2), round(cen[1] / 3600, 2)],
                              "hours_range_all_scenarios": [round(lo_h, 2), round(hi_h, 2)],
                              "hours_range_27_31B_judge": [round(lo_h * BIGGER[0], 2), round(hi_h * BIGGER[1], 2)],
                              "kWh_range": [round(lo_h * WATTS[0] / 1000, 2), round(hi_h * BIGGER[1] * WATTS[1] / 1000, 2)],
                              "electricity_usd_range": [round(lo_h * WATTS[0] / 1000 * USD_KWH[0], 2), round(hi_h * BIGGER[1] * WATTS[1] / 1000 * USD_KWH[1], 2)]}
    return row


JOBS = []
A = PO["pools"]["all"]
G = PO["pools"]["gold"]
for pool, label in (("union_minus_agree_net", "three-way union minus agreement arm, minus spans overlapping the agreement arm (the adjudication queue)"),
                    ("union_minus_agree_exact", "three-way union minus agreement arm by exact span triple (the literal set difference)"),
                    ("control_only", "filtered NLTagger spans overlapping no filtered-sweep span"),
                    ("sweep_only", "filtered-sweep spans overlapping no filtered-NLTagger span"),
                    ("control_only_net", "control_only minus spans overlapping an editor mark"),
                    ("sweep_only_net", "sweep_only minus spans overlapping an editor mark")):
    JOBS.append(job_table("A:" + pool, span_job(A[pool], ACCEPT_B), label))
JOBS.append(job_table("B:agree", span_job(A["agree"], 0.898), "editor ∪ (filtered NLTagger ∩ filtered sweep), sweep-side spans; accept rate = DOCUMENTED presence P 0.898"))


def c_rows(se, arm, classes, counts):
    """per-row chars (low, central, high[, +doc]) weighted over the named classes, from a MEASURED se-pocom run."""
    tot = {"chars": 0, "chars_all": 0, "doc8k": 0, "doc20k": 0, "n": 0}
    for band in ("1861-1899", "1900-1905"):
        for cls in classes:
            S = se["classes"].get("%s|%s|%s" % (arm, band, cls))
            if not S:
                continue
            n = counts.get((band, cls), S["n"])
            if not S.get("chars", {}).get("n"):
                continue
            for f in ("chars", "chars_all", "doc8k", "doc20k"):
                if f in S and S[f].get("n"):
                    tot[f] += n * S[f]["mean"]
            tot["n"] += n
    return tot


CORE = ("contradicted", "several_narrowed_by_location", "seward_assumption")
BROAD = CORE + ("several_unresolved", "several_no_hypothesis")
for arm in ("B", "A"):
    summ_counts = {}
    for band in ("1861-1899", "1900-1905"):
        s = SUMM[(arm, band)]
        summ_counts[(band, "contradicted")] = s["one_contradicted"]
        summ_counts[(band, "several_narrowed_by_location")] = s["several_to_one"] - s["several_to_one_by_secretary_over_same_surname_assistant"]
        summ_counts[(band, "seward_assumption")] = s["several_to_one_by_secretary_over_same_surname_assistant"]
    for label, se, classes, counts in (("summary.json pre-#1292 approximation", SE["pre1292"], CORE, summ_counts),
                                       ("post-#1292 re-measure (this directory)", SE["post1292"], CORE, {}),
                                       ("broad: + unresolved + no-hypothesis several rows, pre-#1292", SE["pre1292"], BROAD, summ_counts),
                                       ("broad, post-#1292", SE["post1292"], BROAD, {})):
        t = c_rows(se, arm, classes, counts)
        n = t["n"]
        JOBS.append(job_table("C:arm%s:%s" % (arm, label), case_job(n, [t["chars"] / n, t["chars"] / n, t["chars_all"] / n]),
                              "rows %d; header+dateline+chapter+classifier+career lines" % n))
        JOBS.append(job_table("C+doc:arm%s:%s" % (arm, label), case_job(n, [(t["chars"] + t["doc8k"]) / n, (t["chars"] + t["doc8k"]) / n, (t["chars_all"] + t["doc20k"]) / n]),
                              "rows %d; the same plus the document's R-0 text capped at 8k (low, central) / 20k (high) chars" % n))

pv = VG["per_volume_input_chars"]
JOBS.append(job_table("D:volume-guide", synth_job([VG["volumes"]] * 3, [VG["per_volume_input_chars_top150_sample40"]["sum"], pv["sample40"]["sum"], pv["sample100"]["sum"]], [1500] * 3),
                      "one ~1,500-word guide per volume; input low = top-150 list + 40 headers, central = full list + 40 headers, high = full list + 100 headers"))
ch = VG["chapters"]
JOBS.append(job_table("D:chapter-guide-1500w", synth_job([ch["with_marked_rows"]] * 3, [ch["input_chars_with_marked"]] * 3, [1500] * 3),
                      "one ~1,500-word guide per chapter that carries at least one marked row"))
JOBS.append(job_table("D:chapter-guide-500w-ge5docs", synth_job([ch["ge5_docs_with_marked"]] * 3, [ch["input_chars_ge5_with_marked"]] * 3, [500] * 3),
                      "one ~500-word note per chapter with >= 5 documents and at least one marked row"))

# ---- E: pilots (one replicate; x3 is linear and reported in the md)
JOBS.append(job_table("E:A-pilot-64docs", span_job(G["union_minus_agree_net"], ACCEPT_B), "the adjudication queue on the 64 keyed M2a documents"))
JOBS.append(job_table("E:B-pilot-64docs", span_job(G["agree"], 0.898), "the agreement arm on the 64 keyed M2a documents"))
idp = SE["pre1292"]["identity_pilot"]["B"]
JOBS.append(job_table("E:C-pilot-100rows", case_job(100, [idp["payload_chars"]["sum"] / 100, idp["payload_chars"]["sum"] / 100, idp["payload_chars_all_appts"]["sum"] / 100]),
                      "the 100 pre-1910 rows of m1a-eval-candidates.csv, arm-B payload"))
JOBS.append(job_table("E:C+doc-pilot-100rows", case_job(100, [(idp["payload_chars"]["sum"] + idp["doc_chars_capped_8000"]) / 100] * 2 + [(idp["payload_chars_all_appts"]["sum"] + idp["doc_chars_capped_20000"]) / 100]),
                      "the same plus document text capped 8k / 8k / 20k"))
for key, label in (("pilot_gold_volumes", "the 24 M2a volumes"), ("pilot_identity_volumes", "the 4 identity-sample volumes")):
    p = VG[key]
    JOBS.append(job_table("E:D-pilot-volume-guides:" + key, synth_job([p["n"]] * 3, [p["input_chars_sample40"], p["input_chars_sample40"], p["input_chars_sample100"]], [1500] * 3), label))

res = {"generated_by": os.path.abspath(__file__),
       "pricing_recorded_in_cost_model": {"PRICE_usd_per_MTok_in_out": PRICE, "batch_multiplier": 0.5, "cache_read_multiplier": 0.1, "cache_write_multiplier": 1.25,
                                          "MINCACHE_tokens": MINCACHE, "PREFIX_tokens": PREFIX, "CACHE_HIT": CACHE_HIT, "THINK": THINK, "MULT_vs_Qwen3": MULT,
                                          "qwen_chars_per_token_MEASURED": QWEN_CPT, "date_or_source_recorded": None},
       "chars_per_whitespace_word_MEASURED": CPW,
       "local_time_model": {"uniform_s_per_token": T_UNIFORM, "prefill_s_per_token": T_PREFILL, "decode_s_per_token": T_DECODE, "decode_prefill_ratio": RATIO,
                            "sweep_s_per_chunk": SWEEP_S / SWEEP_CHUNKS, "watts": WATTS, "usd_per_kWh": USD_KWH, "bigger_judge_factor": BIGGER},
       "jobs": JOBS}
json.dump(res, open(os.path.join(HERE, "cost-jobs.json"), "w"), indent=1)

with open(os.path.join(HERE, "cost-jobs.md"), "w") as f:
    for j in JOBS:
        f.write("\n### %s\n%s\n\n| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |\n|---|---|---|---|---|---|---|---|\n" % (j["job"], j["note"]))
        for model, M in j["models"].items():
            a, b, c = M["low|batch|cached"], M["high|batch|cached"], M["high|standard|uncached"]
            fmt = lambda x: " / ".join("{:,.0f}".format(v) if v >= 100 else "{:,.2f}".format(v) for v in x)
            f.write("| %s | %s | %s | %s | %s | %s | %s | %s |\n" % (model, fmt(a["usd"]), fmt(b["usd"]), fmt(c["usd"]), " / ".join(map(str, a["input_MTok"])),
                                                                      " / ".join(map(str, a["visible_output_MTok"])), b["thinking_MTok"][1], a["batches"][1]))
        for mode, L in j["local"].items():
            f.write("\nlocal %s: Qwen in/out MTok (central) %s / %s; hours central %s; hours range %s; 27-31B judge %s; kWh %s; $ %s\n" % (
                mode, L["qwen_in_MTok"][1], L["qwen_out_MTok"][1], L["hours_central_scenario_two_time_models"], L["hours_range_all_scenarios"],
                L["hours_range_27_31B_judge"], L["kWh_range"], L["electricity_usd_range"]))
print("wrote", len(JOBS), "jobs")
