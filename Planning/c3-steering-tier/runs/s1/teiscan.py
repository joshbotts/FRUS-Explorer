import re, glob, os, csv, sys, collections
V="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes/"
tag=re.compile(r"<[^>]+>"); ws=re.compile(r"\s+")
variants={
 "corruption":r"\bcorruption\b","corrupt(adj)":r"\bcorrupt\b","corrupted":r"\bcorrupted\b","corruptly":r"\bcorruptly\b","corrupting/corrupts":r"\bcorrupt(?:ing|s)\b",
 "corruptionist":r"\bcorruptionists?\b",
 "bribe":r"\bbribes?\b","bribed/bribing":r"\bbrib(?:ed|ing)\b","bribery":r"\bbribery\b",
 "graft":r"\bgraft\b","kickback":r"\bkick-?backs?\b","embezzle*":r"\bembezzl\w+","venal*":r"\bvenal\w*","malfeasance":r"\bmalfeasance\b",
 "nepotism":r"\bnepotism\b","cronyism":r"\bcronyism\b","payoff":r"\bpay-?offs?\b","peculation":r"\bpeculat\w+","squeeze":r"\bsqueeze\b",
 "questionable payments":r"\bquestionable (?:payments?|practices)\b","FCPA":r"\bFCPA\b","Foreign Corrupt Practices":r"\bForeign Corrupt Practices\b",
 "CONTROL+ Department of State":r"\bDepartment of State\b","CONTROL- ZZZ_IMPOSSIBLE_ZZZ":r"ZZZ_IMPOSSIBLE_ZZZ",
}
rx={k:re.compile(v,re.I if not k.startswith("FCPA") else 0) for k,v in variants.items()}
out=csv.writer(open("teiscan.csv","w"))
out.writerow(["volume"]+list(variants))
for i,f in enumerate(sorted(glob.glob(V+"*.xml"))):
    t=open(f,encoding="utf-8",errors="replace").read()
    t=ws.sub(" ",tag.sub(" ",t))
    out.writerow([os.path.basename(f)[:-4]]+[len(r.findall(t)) for r in rx.values()])
    if i%50==0: print(i,flush=True)
print("done",flush=True)
