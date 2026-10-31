import re, json, glob, sys
t=open("overview.md").read()
QV=json.load(open("quotes_verified.json"))
alltext={}
for f in glob.glob("docs/*.txt"):
    alltext[f]=re.sub(r"\s+"," ",open(f).read())
spans=re.findall(r"“(.+?)”",t)
print("curly-quoted spans:",len(spans))
bad=[]
for sp in spans:
    spn=sp.strip()
    ok_q=[q["id"] for q in QV if spn in q["text"] or q["text"] in spn]
    ok_d=[f for f,b in alltext.items() if spn in b]
    print(("OK " if ok_q else ("DOC " if ok_d else "?? ")),spn[:90],"|",ok_q[:3])
    if not ok_q and not ok_d: bad.append(spn)
print("UNVERIFIED:",bad)
# URLs -> keys
urls=sorted(set(re.findall(r"historicaldocuments/([^/\s]+)/([^\s)]+)",t)))
keys=set(k.replace("/","|") for k in json.load(open("meta.json")))
cited={"%s|%s"%u for u in urls}
print("cited docs",len(cited),"not in meta:",cited-keys,"meta not cited:",keys-cited)
# forbidden
for pat in [r"document_cache",r"volume_id",r"SELECT ",r"/Users/",r"#\d{3,4}"]:
    print(pat, len(re.findall(pat,t)))
