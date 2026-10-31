import sys,re,glob
rx=re.compile(sys.argv[1],re.I)
for f in sys.argv[2:]:
    x=" ".join(open(f).read().split())
    for m in rx.finditer(x):
        print(f.split("/")[-1],"::",x[max(0,m.start()-300):m.end()+250]); print()
