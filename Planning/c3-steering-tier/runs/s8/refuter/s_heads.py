import re, glob, os
D="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes"
pat=re.compile(r"corrupt|brib|lockheed|illicit payment|questionable payment|improper payment|payoff|graft\b|kickback|venal",re.I)
head=re.compile(r"<head\b[^>]*>(.*?)</head>",re.S)
pos=neg=hits=0; files=0; out=open("/Users/jbotts/frus-analysis/c3s/runs/s8/refuter/heads_hits.txt","w")
for f in sorted(glob.glob(D+"/*.xml")):
    files+=1; t=open(f,encoding="utf-8").read(); v=os.path.basename(f)[:-4]
    for h in head.findall(t):
        s=" ".join(re.sub(r"<[^>]+>"," ",h).split())
        if "Memorandum" in s: pos+=1
        if "ZZZ_IMPOSSIBLE_ZZZ" in s: neg+=1
        if pat.search(s): hits+=1; out.write(v+" | "+s[:250]+"\n")
print("files",files,"heads hit",hits,"positive control 'Memorandum'",pos,"negative",neg)
