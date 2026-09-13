#!/usr/bin/env python3
"""vcost.py — independent recomputation of the central (and low/high) dollar and local-hour figures for jobs A (queue),
B (agreement arm), C (arm B, summary.json counts) and D (volume guide), from MY measured pool volumes (vpools.json,
vpack.json) and the measured run's C/D per-row/per-volume char sizes (their JSON, read as DOCUMENTED inputs).
Treatment = cost_model.py's, re-typed from reading it (constants asserted against its source text). No API."""
import sys; sys.dont_write_bytecode = True
import os, json, math
HERE = os.path.dirname(os.path.abspath(__file__))
SP = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad"
M = SP + "/reframe/measure-claude-jobs"
CMS = open(SP + "/llm-pass/cost-scale/cost_model.py").read()
for frag in ('PRICE = {"haiku-4.5": (1.0, 5.0), "sonnet-5": (2.0, 10.0), "opus-5": (5.0, 25.0)}',
             'MULT = {"haiku-4.5": (1.00, 1.12, 1.25), "sonnet-5": (1.30, 1.46, 1.63), "opus-5": (1.00, 1.31, 1.69)}',
             'PREFIX = (1100, 3000, 6000)', 'CACHE_HIT = (1.0, 0.9, 0.5)', 'if batch: dollars *= 0.5'):
    assert frag in CMS, frag
PRICE = {"haiku-4.5": (1.0, 5.0), "sonnet-5": (2.0, 10.0), "opus-5": (5.0, 25.0)}
MULT = {"haiku-4.5": (1.00, 1.12, 1.25), "sonnet-5": (1.30, 1.46, 1.63), "opus-5": (1.00, 1.31, 1.69)}
MINC = {"haiku-4.5": 4096, "sonnet-5": 1024, "opus-5": 512}
PREFIX, HIT = (1100, 3000, 6000), (1.0, 0.9, 0.5)
THINK = {"span": {"low": (0.1, 50), "high": (1.0, 500)}, "case": {"low": (0.3, 100), "high": (2.0, 1500)}}
AN = json.load(open(SP + "/llm-pass/cost-scale/analysis.json"))
CPT = AN["anchor_regression"]["chars_per_token"]; OVH = AN["anchor_regression"]["overhead_tokens_per_chunk"]
VPO = json.load(open(os.path.join(HERE, "vpools.json")))["all"]; VPK = json.load(open(os.path.join(HERE, "vpack.json")))
CPW = VPO["chars"] / 113031709.0   # whitespace words: re-used from pools.json (not re-measured here)

def span(p):
    sp, pr, ks = VPO["spans:" + p], VPO["pairs:" + p], None
    return [dict(k="span", req=VPK[p]["req_pack40000"], ch=VPO["win_merged:" + p] + VPO["listing:" + p] * pr / sp, dec=pr),
            dict(k="span", req=VPK[p]["req_pack20000"], ch=VPO["win_merged:" + p] + VPO["listing:" + p], dec=sp),
            dict(k="span", req=VPO["docs:" + p], ch=VPO["win_unmerged:" + p] + VPO["listing:" + p], dec=sp)]

def cost(model, d, i, effort, batch, cached, accept):
    pin, pout = PRICE[model]; mult = MULT[model][i]; cpt = CPT / mult
    vin = d["ch"] / cpt + d["req"] * 30
    if d["k"] == "span":
        r, a = [(5, 9), (7, 12), (10, 20)][i]
        vis = d["dec"] * (accept[i] * a + (1 - accept[i]) * r) * mult / MULT[model][1] + d["req"] * 20
        tk = "span"
    elif d["k"] == "case":
        vis = d["rows"] * [15, 25, 45][i] + d["req"] * 10; tk = "case"
    else:
        vis = d["req"] * d["words"] * CPW / cpt; tk = "case"
    a_, b_ = THINK[tk][effort]
    if model == "haiku-4.5" and effort == "low":
        a_, b_ = 0, 0
    think = a_ * vis + b_ * d["req"]
    ok = cached and PREFIX[i] >= MINC[model]; h = HIT[i] if ok else 0
    pref = PREFIX[i] * d["req"]
    usd = ((vin + pref * (1 - h)) * pin + pref * h * pin * 0.1 + (math.ceil(d["req"] / 1000) * PREFIX[i] * pin * 1.25 if ok else 0) + (vis + think) * pout) / 1e6
    usd *= 0.5 if batch else 1
    qin = d["ch"] / CPT + d["req"] * (OVH + (0 if i == 0 else PREFIX[i]))
    qout = vis if model == "haiku-4.5" else None
    return usd, vin + pref, vis, qin

se = json.load(open(M + "/se-pocom-cases-pre1292.json"))
summ = {(s["arm"], s["band"]): s for s in json.load(open(SP + "/chapter-context/coverage/summary.json"))}
n = chars = chars_all = 0
for b in ("1861-1899", "1900-1905"):
    s = summ[("B", b)]
    for cls, cnt in (("contradicted", s["one_contradicted"]), ("several_narrowed_by_location", s["several_to_one"] - s["several_to_one_by_secretary_over_same_surname_assistant"]),
                     ("seward_assumption", s["several_to_one_by_secretary_over_same_surname_assistant"])):
        S = se["classes"].get("B|%s|%s" % (b, cls))
        if not S or not cnt:
            continue
        n += cnt; chars += cnt * S["chars"]["mean"]; chars_all += cnt * S["chars_all"]["mean"]
C = [dict(k="case", req=math.ceil(n / kk), ch=cc, rows=n) for kk, cc in ((50, chars), (25, chars), (10, chars_all))]
vg = json.load(open(M + "/volume-guides.json"))
D = [dict(k="synth", req=267, ch=vg["per_volume_input_chars_top150_sample40"]["sum"], words=1500),
     dict(k="synth", req=267, ch=vg["per_volume_input_chars"]["sample40"]["sum"], words=1500),
     dict(k="synth", req=267, ch=vg["per_volume_input_chars"]["sample100"]["sum"], words=1500)]
JOBS = {"A:queue": (span("Q"), [0.49, 0.49, 0.60]), "B:agree": (span("AG"), [0.898] * 3), "C:armB": (C, None), "D:volume": (D, None)}
T_PT, T_CT, T_S = 220645005, 21131474, 997807.6
R = 75 / 6.2; tu = T_S / (T_PT + T_CT); tp = T_S / (T_PT + R * T_CT)
out = {"inputs": {"cpt_qwen": CPT, "qwen_overhead_tok": OVH, "C_rows": n, "C_chars_per_row": chars / n, "A_req": [d["req"] for d in JOBS["A:queue"][0]], "B_req": [d["req"] for d in JOBS["B:agree"][0]]},
       "local_time_model": {"uniform_ms_per_tok": tu * 1e3, "prefill_ms": tp * 1e3, "decode_ms": tp * R * 1e3, "sweep_hours": T_S / 3600}, "jobs": {}}
tot = {}
for name, (sc, acc) in JOBS.items():
    J = {}
    for model in PRICE:
        for label, eff, bat, cac in (("low|batch|cached", "low", True, True), ("high|standard|uncached", "high", False, False)):
            vals = [cost(model, sc[i], i, eff, bat, cac, acc) for i in range(3)]
            J["%s %s" % (model, label)] = {"usd": [round(v[0], 1) for v in vals], "in_MTok_central": round(vals[1][1] / 1e6, 2), "vis_MTok_central": round(vals[1][2] / 1e6, 2)}
            key = "%s %s" % (model, label)
            tot[key] = [tot.get(key, [0, 0, 0])[k] + vals[k][0] for k in range(3)]
    # local, central scenario, Haiku-central visible output / 1.12 as Qwen tokens, no think
    d = sc[1]; usd, vin, vis, qin = cost("haiku-4.5", d, 1, "low", True, True, acc)
    qout = vis / 1.12
    J["local_central_hours_uniform_vs_split"] = [round((qin + qout) * tu / 3600, 1), round((qin * tp + qout * tp * R) / 3600, 1)]
    out["jobs"][name] = J
out["headline_totals"] = {k: [round(x) for x in v] for k, v in tot.items()}
out["local_headline_hours"] = [round(sum(out["jobs"][j]["local_central_hours_uniform_vs_split"][k] for j in JOBS), 1) for k in (0, 1)]
json.dump(out, open(os.path.join(HERE, "vcost.json"), "w"), indent=1)
print(json.dumps(out, indent=1))
