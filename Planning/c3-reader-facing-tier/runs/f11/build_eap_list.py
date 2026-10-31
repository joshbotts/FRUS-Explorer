import json,re
m=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
pat=re.compile(r"China|Japan|Korea|Vietnam|Indochina|Southeast Asia|East Asia|Northeast Asia|Pacific|Indonesia|Philippines|Laos|Cambodia|Asia|Malaysia|Taiwan",re.I)
out=[]
for v in m:
    fn=v["filename"][:-4]
    t=re.sub(r"\s+"," ",v["title"])
    yr=re.search(r"(19\d\d)",fn)
    if not re.match(r"frus(19[4-8]\d)",fn): continue
    if pat.search(t) and "Ed2" not in fn and "Supp" not in fn:
        out.append((fn,t))
open("eap_volumes.txt","w").write("\n".join(f for f,_ in out)+"\n")
for f,t in out: print(f,"|",t[40:130])
print(len(out))
