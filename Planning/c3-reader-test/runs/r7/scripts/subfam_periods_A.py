# Sub-family hits by period INSIDE CHANNEL A (the FTS-defined set), with channel-A denominators, as "n/N".
import collections, glob, os
R="/Users/jbotts/frus-analysis/c3/runs/r7/out/"
def period(iso):
    y=int(iso[:4]) if iso[:4].isdigit() else 0
    for lo,hi,lab in ((0,1908,"1861-1908"),(1909,1920,"1909-1920"),(1921,1932,"1921-1932"),(1933,1942,"1933-1942"),(1943,1951,"1943-1951"),(1952,1960,"1952-1960"),(1961,1968,"1961-1968"),(1969,1976,"1969-1976"),(1977,1988,"1977-1988")):
        if lo<=y<=hi: return lab
    return "?"
periods=["1861-1908","1909-1920","1921-1932","1933-1942","1943-1951","1952-1960","1961-1968","1969-1976","1977-1988"]
A={}
for l in list(open(R+"core_set.tsv"))[1:]:
    v,d,iso,a,b,p=l.rstrip("\n").split("\t")
    if a=="1": A[(v,d)]=period(iso)
base=collections.Counter(A.values())
print("channel A by period:", "\t".join(f"{p}:{base[p]}" for p in periods))
out=open(R+"subfam_periods_A.tsv","w"); out.write("family\tA_hits\t"+"\t".join(periods)+"\n")
for fn in sorted(glob.glob(R+"subfam_*.tsv")):
    name=os.path.basename(fn)[7:-4]
    if name in ("census_summary","periods_A"): continue
    c=collections.Counter()
    for l in open(fn):
        v,d,flag=l.rstrip("\n").split("\t")
        if (v,d) in A: c[A[(v,d)]]+=1
    line=f"{name}\t{sum(c.values())}\t"+"\t".join(f"{c[p]}/{base[p]}" for p in periods)
    print(line); out.write(line+"\n")
out.close()
