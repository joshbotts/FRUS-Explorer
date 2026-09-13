import sys,random,re
sys.argv=[sys.argv[0]]
# reuse score_mine's machinery by exec of its top portion up to the bootstrap definitions
src=open(__file__.replace("sim8.py","score_mine.py")).read().split("# bootstrap")[0]
import io,contextlib
with contextlib.redirect_stdout(io.StringIO()): exec(src)
N=10000
for extra in ({"1900-1929":3,"1930-1945":3,"1946-":2},{"1900-1929":2,"1930-1945":3,"1946-":3}):
    for repl in (True,False):
        rng=random.Random(7); met=0; gaps=[]
        for _ in range(N):
            s=list(docs)
            for b,n in extra.items():
                pool=[k for k in docs if band[k]==b]
                s+= [rng.choice(pool) for _ in range(n)] if repl else rng.sample(pool,n)
            met+=rule_met(s); gaps.append(gap("nltagger","raw_sweep",s,"strict"))
        print("extra",extra,"with_replacement",repl,"rule met",met,"of",N,"strict gap range %.1f to %.1f"%(min(gaps),max(gaps)))
