import sys,re,os
# usage: python3 ctx.py vol/doc [width] -> windows around corruption-family words, from the whole-document text on disk (run getdoc.py first)
pat=re.compile(r"corrupt|brib|graft|kickback|payoff|venal|embezzl|nepot|scandal|squeeze|malfeas",re.I)
w=int(sys.argv[2]) if len(sys.argv)>2 else 350
v,d=sys.argv[1].split("/")
t=re.sub(r"\s+"," ",open(f"work/docs/{v}__{d}.txt").read())
last=-1
for m in pat.finditer(t):
    if m.start()<last: continue
    a=max(0,m.start()-w); b=min(len(t),m.end()+w); last=b
    print("…"+t[a:b]+"…\n")
