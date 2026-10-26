# Decade shape of the core set (channel A = FTS NEAR family within Latin American documents; A|B adds the curated headings),
# per 1,000 dated non-apparatus documents of the decade (out/decade_denominators.tsv), with the top volume's share of each numerator.
import collections
R="/Users/jbotts/frus-analysis/c3/runs/r7/out/"
den={}
for l in open(R+"decade_denominators.tsv"):
    if l.startswith("decade"): continue
    d,n=l.strip().split("|"); den[d]=int(n)
rows=[l.rstrip("\n").split("\t") for l in open(R+"core_set.tsv")][1:]
for label, pred in (("A (FTS family in Latin American docs)", lambda r: r[3]=="1"), ("A|B (plus curated recognition headings)", lambda r: True)):
    cnt=collections.Counter(); vol=collections.defaultdict(collections.Counter)
    for v,d,iso,a,b,p in rows:
        if not pred((v,d,iso,a,b,p)): continue
        dec=(iso[:3]+"0s") if iso else "undated"
        cnt[dec]+=1; vol[dec][v]+=1
    print("##",label)
    print("decade\tn\tdenominator\tper_1000\ttop_volume\ttop_share")
    for dec in sorted(cnt):
        n=cnt[dec]; D=den.get(dec,0)
        tv,tn=vol[dec].most_common(1)[0]
        print(f"{dec}\t{n}\t{D}\t{(1000*n/D if D else 0):.2f}\t{tv}\t{tn} of {n}")
