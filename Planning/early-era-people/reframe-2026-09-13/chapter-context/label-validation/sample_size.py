#!/usr/bin/env python3
"""Wilson 95% bounds for a keyed identity sample: the lower bound after n picks with e errors, and the
n needed for a lower bound >= target at a given true precision (expected errors rounded)."""
import math, json
def wl(k,n,z=1.96):
    p=k/n; den=1+z*z/n; c=(p+z*z/(2*n))/den; h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den; return round(c-h,4), round(c+h,4)
out={"zero_errors_lower_bound":{n:wl(n,n)[0] for n in (20,30,50,75,100,150,200,300)},
     "halfwidth_at_p":{str(p):{n:round((wl(round(p*n),n)[1]-wl(round(p*n),n)[0])/2,4) for n in (30,50,100,200)} for p in (0.8,0.9,0.95)}}
need={}
for p in (0.9,0.95,0.98):
    for target in (0.8,0.9):
        n=next((n for n in range(5,3000) if wl(round(p*n),n)[0]>=target),None); need[f"p={p},lower>={target}"]=n
out["n_needed"]=need
print(json.dumps(out,indent=1)); json.dump(out,open("sample-size.json","w"),indent=1)
