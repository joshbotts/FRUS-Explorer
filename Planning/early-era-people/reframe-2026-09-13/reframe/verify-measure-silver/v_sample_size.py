#!/usr/bin/env python3
"""VERIFY sample-size arithmetic independently: Wilson score lower bound (z=1.96) by bisection-free closed form written
from the textbook formula; zero-error and one-error bounds; exact one-sided binomial transfer test with power computed by
summing the pmf iteratively (no lgamma). Also Clopper-Pearson-free 'rule of three'-style exact upper bound for 0 of n."""
import math, json, os
Z=1.959963984540054
def wilson_lo(k,n,z=Z):
    p=k/n; a=p+z*z/(2*n); b=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n)); return (a-b)/(1+z*z/n)
def pmf_list(n,p):
    # iterative pmf from k=0 in log space
    out=[]; lq=math.log1p(-p); lp=math.log(p); lc=0.0
    for k in range(n+1):
        if k>0: lc+=math.log(n-k+1)-math.log(k)
        out.append(math.exp(lc+k*lp+(n-k)*lq))
    return out
def transfer_n(p0,p1,alpha=0.05,power=0.80):
    for n in range(10,2000):
        f0=pmf_list(n,p0); f1=pmf_list(n,p1)
        cum=0.0; c=-1
        for k in range(n+1):
            if cum+f0[k]<=alpha: cum+=f0[k]; c=k
            else: break
        if c<0: continue
        if sum(f1[:c+1])>=power: return n
    return None
res={"zero_error_lo":{n:round(wilson_lo(n,n),4) for n in (12,25,50,60,100,127)},
     "one_error_lo_100":round(wilson_lo(99,100),4),
     "n_for_lo_ge_0.90":{p:next((n for n in range(5,5000) if wilson_lo(round(p*n),n)>=0.90),None) for p in (0.99,0.98,0.97,0.95,0.93,0.90)},
     "transfer":{f"{a}->{b}":transfer_n(a,b) for a,b in ((0.99,0.95),(0.99,0.93),(0.99,0.90),(0.96,0.90))},
     "exact_upper_0_of_n_one_sided95":{n:round(1-0.05**(1/n),4) for n in (30,50)},
     "exact_upper_0_of_n_two_sided95":{n:round(1-0.025**(1/n),4) for n in (30,50)}}
json.dump(res,open(os.path.dirname(os.path.abspath(__file__))+"/v-sample-size.json","w"),indent=1); print(json.dumps(res,indent=1))
