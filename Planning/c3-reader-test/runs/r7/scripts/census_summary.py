import collections
R="/Users/jbotts/frus-analysis/c3/runs/r7/out/"
rows=[l.rstrip("\n").split("\t") for l in open(R+"literal_census.tsv")][1:]
def share(sel, label):
    n=len(sel); t=sum(int(r[4]) for r in sel); s=sum(int(r[5]) for r in sel)
    print(f"{label}: TOLERANT {t} of {n} = {t/n:.3f}; STRICT {s} of {n} = {s/n:.3f}")
A=[r for r in rows if r[2]=="1"]; Bonly=[r for r in rows if r[2]=="0"]; AB=rows
share(A,"channel A (FTS NEAR family, Latin American docs)")
share(Bonly,"B-only (curated recognition headings, no FTS hit)")
share(AB,"A|B (core set)")
# misses in A
miss=[r for r in A if r[4]=="0"]
print("A tolerant misses:", len(miss)); 
for r in miss[:40]: print("  ", r[0], r[1], "strict=",r[5], "chars=",r[6])
# by decade for A
dec=collections.defaultdict(lambda:[0,0,0])
for r in A:
    pass
