import re, glob, os, json, sys, collections
V="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes/"
PAT = collections.OrderedDict([
 ("Department of State (POSITIVE control)", r"\bDepartment of State\b"),
 ("ZZZ_IMPOSSIBLE_ZZZ (NEGATIVE control)", r"ZZZ_IMPOSSIBLE_ZZZ"),
 ("corruption", r"\bcorruption\b"), ("corrupt", r"\bcorrupt\b"), ("corrupted", r"\bcorrupted\b"), ("corrupting", r"\bcorrupting\b"), ("corruptly", r"\bcorruptly\b"),
 ("bribery", r"\bbribery\b"), ("bribe/bribes", r"\bbribes?\b"), ("bribed/bribing", r"\b(?:bribed|bribing)\b"),
 ("graft", r"\bgraft\b"), ("peculation", r"\bpeculation\b"), ("defalcation(s)", r"\bdefalcations?\b"), ("malversation", r"\bmalversations?\b"),
 ("embezzlement/embezzle*", r"\bembezzl\w*"), ("kickback(s)", r"\bkick-?backs?\b"), ("payoff(s)", r"\bpay-?offs?\b"),
 ("venal/venality", r"\bvenal(?:ity)?\b"), ("squeeze (Chinese/Levantine sense not separated)", r"\bsqueeze\b"),
 ("illicit payment(s)", r"\billicit payments?\b"), ("questionable payment(s)", r"\bquestionable payments?\b"),
 ("Foreign Corrupt Practices Act", r"\bForeign Corrupt Practices Act\b"), ("FCPA", r"\bFCPA\b"),
 ("anti-corruption / anticorruption", r"\banti-?corruption\b"), ("corrupt practices", r"\bcorrupt practices\b"),
])
CP={k:re.compile(v,re.I) for k,v in PAT.items()}
tag=re.compile(r"<[^>]+>")
tot=collections.Counter(); docs=collections.Counter(); byvol={}
files=sorted(glob.glob(V+"*.xml"))
out=open("tei_scan_progress.txt","w")
for i,f in enumerate(files):
    vid=os.path.basename(f)[:-4]
    if vid in ("frus1951-54IranEd2","frus1969-76ve15p2Ed2"): continue
    t=" ".join(tag.sub(" ",open(f,encoding="utf-8",errors="replace").read()).split())
    row={}
    for k,rx in CP.items():
        n=len(rx.findall(t)); tot[k]+=n; row[k]=n
    byvol[vid]=row
    if i%25==0: out.write(f"{i}/{len(files)} {vid}\n"); out.flush()
json.dump({"totals":tot,"byvol":byvol,"files_scanned":len(byvol)},open("tei_scan.json","w"))
out.write("DONE\n"); out.close()
