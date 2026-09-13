#!/usr/bin/env python3
"""Task 3 sizing. (1) Wilson 95% intervals: zero-error lower bound at n; n needed for a lower bound >= 0.80/0.90 at
true precision 0.90..0.99 (expected errors rounded). (2) Exact one-sided binomial: n needed to REJECT 'pre-1900 precision
>= p_silver' at alpha 0.05 with power 0.80 when the true pre-1900 precision is lower (the transfer test: does the silver
number carry over?). (3) Stratum availability in the untagged 1861-1899 population at head grain, read from
chapter-context/coverage/chapter-rule.json tallies['B|1861-1899|head'] (arm B = title repairs applied), so every
proposed stratum is drawable."""
import math, json
def wilson(k,n,z=1.96):
    p=k/n; den=1+z*z/n; c=(p+z*z/(2*n))/den; h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den; return c-h, c+h
def lower(p,n): return wilson(round(p*n),n)[0]
out={}
out["zero_error_lower_bound"]={n:round(wilson(n,n)[0],4) for n in (8,12,17,25,30,40,50,60,63,75,100,127,150,200)}
out["one_error_lower_bound"]={n:round(wilson(n-1,n)[0],4) for n in (25,50,60,75,100,127,150,200)}
need={}
for p in (0.90,0.93,0.95,0.97,0.98,0.99):
    for tgt in (0.80,0.85,0.90):
        need[f"true={p},lower>={tgt}"]=next((n for n in range(5,4000) if lower(p,n)>=tgt),None)
out["n_needed_wilson"]=need
def binom_cdf(k,n,p):
    s=0.0; q=1-p
    lp=0.0
    # stable via log
    for i in range(0,k+1):
        s+=math.exp(math.lgamma(n+1)-math.lgamma(i+1)-math.lgamma(n-i+1)+i*math.log(p)+(n-i)*math.log(q)) if 0<p<1 else (1.0 if (p==0 and i==0) else 0.0)
    return s
def n_transfer(p0,p1,alpha=0.05,power=0.80):
    # H0: precision >= p0 ; reject when correct picks <= c ; want P(reject | p1) >= power
    for n in range(10,3000):
        c=-1
        for k in range(n+1):
            if binom_cdf(k,n,p0)<=alpha: c=k
            else: break
        if c>=0 and binom_cdf(c,n,p1)>=power: return n
    return None
out["n_to_detect_transfer_gap_alpha05_power80"]={f"silver={p0},true_pre1900={p1}":n_transfer(p0,p1) for p0,p1 in ((0.99,0.95),(0.99,0.93),(0.99,0.90),(0.96,0.90),(0.96,0.85),(0.93,0.85))}
S="/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad"
cr=json.load(open(S+"/chapter-context/coverage/chapter-rule.json"))
t=cr["tallies"]["B|1861-1899|head"]
keys=[k for k in t if k.startswith(("pocom:","T:several","T:one","T:nobody","T:unknown","combined:","grain:","rows","explained_by:"))]
out["untagged_1861_1899_head_grain_armB"]={k:t[k] for k in sorted(keys)}
te=cr["tallies"].get("B|1861-1899|enclosure",{})
out["untagged_1861_1899_enclosure_rows_armB"]=te.get("rows")
out["seward_1861_1869_armB"]=cr.get("seward_1861_1869_armB")
json.dump(out,open("sample-design.json","w"),indent=1)
print(json.dumps(out,indent=1)[:6000])
