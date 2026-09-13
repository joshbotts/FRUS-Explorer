#!/usr/bin/env python3
"""Pilot token + dollar cost from MEASURED character counts (stage1_sizing.json, stage2_sizing.json).
Every token figure is INFERRED from characters: no tokenizer or API was called.
Conversion bracket: 4.652 chars/token (MEASURED for Qwen3's tokenizer on this corpus, stage1 fit) as the LOW-cost end,
3.0 chars/token as the HIGH-cost end (Claude tokenizers unmeasured here; Sonnet 5 documented ~30% more tokens than Sonnet 4.6)."""
import json, os
HERE=os.path.dirname(os.path.abspath(__file__))
s1=json.load(open(os.path.join(HERE,"stage1_sizing.json"))); s2=json.load(open(os.path.join(HERE,"stage2_sizing.json")))
PRICE={"claude-opus-5":(5.0,25.0),"claude-sonnet-5":(2.0,10.0)}
CPT={"low":4.652,"high":3.0}
INSTR=1500      # INFERRED: frozen instructions (M2a-INSTRUCTIONS.md 2,547 B + conventions + schema), tokens
HEADER=60       # volume id, title, coverage dates
REPS=3          # replicate runs per arm: hosted models accept no sampling params, so variance is measured
THINK_FLAT=4000 # INFERRED high-effort thinking ALLOWANCE per request (a ceiling for budgeting, not a prediction)
DOCS=s1["documents"]; CH=s1["r0_chars_total"]; GOLD=s1["gold_mentions"]
PRED=2*GOLD                         # detection output sized at 2x gold (the filtered sweep emitted 736)
CAND=s1["three_way_union_distinct_offsets_total"]   # 906 candidates to adjudicate
def arms(cpt):
    dt=CH/cpt
    return {
     "S1-b detect, surface+context JSON":dict(inp=DOCS*(INSTR+HEADER)+dt, out=PRED*45 + DOCS*THINK_FLAT + dt),
     "S1-a detect, bracket echo":        dict(inp=DOCS*(INSTR+HEADER)+dt, out=dt*1.05 + PRED*4 + DOCS*THINK_FLAT + dt),
     "S1-c adjudicate 3-way union":      dict(inp=DOCS*(INSTR+HEADER)+dt+CAND*50, out=CAND*20 + DOCS*THINK_FLAT + dt),
    }
def s2arm(cpt, rows_frac):
    rows=s2["rows"]*rows_frac
    dt=s2["doc_chars"]["total_capped_20000"]*rows_frac/cpt
    cand=(s2["pocom_appointments_per_row"]["total"]*30 + s2["pocom_candidates_per_row"]["total"]*20)*rows_frac
    return dict(inp=rows*(INSTR+HEADER)+dt+cand, out=rows*(200+6000))
res={}
for end,cpt in CPT.items():
    a=arms(cpt); a["S2 identity, 100 pre-1910 rows"]=s2arm(cpt,100/300); a["S2 identity, all 300 rows"]=s2arm(cpt,1.0)
    for name,t in a.items():
        for m,(pi,po) in PRICE.items():
            one=(t["inp"]*pi+t["out"]*po)/1e6
            res.setdefault(name,{}).setdefault(m,{})[end]={"input_tok_per_run":round(t["inp"]),"output_tok_per_run_ceiling":round(t["out"]),
                "usd_per_run":round(one,2),"usd_x%d_reps"%REPS:round(one*REPS,2),"usd_x%d_reps_batch"%REPS:round(one*REPS/2,2)}
tot={}
for m in PRICE:
    for end in CPT:
        s1tot=sum(res[k][m][end]["usd_x3_reps"] for k in res if k.startswith("S1"))
        tot["%s/%s"%(m,end)]={"stage1_all_three_arms_x3":round(s1tot,2),
            "stage2_300_rows_x3":res["S2 identity, all 300 rows"][m][end]["usd_x3_reps"],
            "stage2_100_rows_x3":res["S2 identity, 100 pre-1910 rows"][m][end]["usd_x3_reps"]}
tot["both_models_everything_high_end_standard"]=round(sum(v["stage1_all_three_arms_x3"]+v["stage2_300_rows_x3"] for k,v in tot.items() if k.endswith("/high")),2)
out={"assumptions":{"chars_per_token":CPT,"instr_tokens":INSTR,"header_tokens":HEADER,"reps":REPS,"thinking_allowance_per_request":THINK_FLAT,
     "extra_thinking_allowance":"+1x document tokens per S1 request; S2 flat 6000","pred_mentions":PRED,"candidates":CAND,"s1_chars":CH,"s2_chars_capped_20000":s2["doc_chars"]["total_capped_20000"]},
     "arms":res,"totals":tot}
json.dump(out,open(os.path.join(HERE,"pilot_cost.json"),"w"),indent=1)
for k,v in res.items():
    for m in PRICE:
        print("%-36s %-16s low %6.2f  high %6.2f  (x3 reps, standard)  in/run high %7d out/run ceiling %7d"%(k,m,v[m]["low"]["usd_x3_reps"],v[m]["high"]["usd_x3_reps"],v[m]["high"]["input_tok_per_run"],v[m]["high"]["output_tok_per_run_ceiling"]))
print(json.dumps(tot,indent=1))
