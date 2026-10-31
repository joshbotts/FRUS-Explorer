# Scan every TEI <head> (tag-stripped, whitespace-collapsed) for corruption vocabulary; positive control 'Memorandum', negative 'ZZZ_IMPOSSIBLE_ZZZ'
import re, glob, os, sys
D="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes"
pat=re.compile(r"corrupt|brib|lockheed|illicit payment|questionable payment|improper payment|payoff|graft\b|kickback|venal",re.I)
head=re.compile(r"<head\b[^>]*>(.*?)</head>",re.S)
pos=neg=0; out=open("raw/heads_hits.txt","w")
for f in sorted(glob.glob(D+"/*.xml")):
    t=open(f,encoding="utf-8").read(); v=os.path.basename(f)[:-4]
    for h in head.findall(t):
        s=" ".join(re.sub(r"<[^>]+>"," ",h).split())
        if "Memorandum" in s: pos+=1
        if "ZZZ_IMPOSSIBLE_ZZZ" in s: neg+=1
        if pat.search(s): out.write(v+" | "+s[:250]+"\n")
    out.flush()
print("positive control heads containing 'Memorandum':",pos,"negative control:",neg)
