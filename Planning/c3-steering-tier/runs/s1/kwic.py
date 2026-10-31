import re, sys
rx=re.compile(sys.argv[2] if len(sys.argv)>2 else r"corrupt|brib|graft|kick-?back|embezzl|venal",re.I)
w=int(sys.argv[3]) if len(sys.argv)>3 else 350
t=re.sub(r"\s+"," ",open(sys.argv[1]).read())
last=-10**9
for m in rx.finditer(t):
    if m.start()<last+w: continue
    last=m.end()
    print("...",t[max(0,m.start()-w):m.end()+w],"...\n")
