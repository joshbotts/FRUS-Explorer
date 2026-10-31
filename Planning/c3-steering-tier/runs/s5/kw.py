import re, sys
# usage: kw.py vol/doc [regex] [width]  -- prints keyword-in-context from the dumped file
a=sys.argv[1]; v,d=a.split("/")
rx=re.compile(sys.argv[2] if len(sys.argv)>2 else r"corrupt|brib|graft|embezzl|kickback|payoff|venal", re.I)
w=int(sys.argv[3]) if len(sys.argv)>3 else 300
t=" ".join(open(f"docs/{v}__{d}.txt",encoding="utf-8").read().split())
last=-10**9
for m in rx.finditer(t):
    if m.start()-last < w: continue
    last=m.start()
    print(f"[{m.start()}/{len(t)}] ...{t[max(0,m.start()-w):m.end()+w]}...\n")
