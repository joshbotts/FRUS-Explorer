import re, html
V = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes/"
nine = ["frus1961-63v10","frus1961-63v11","frus1961-63v12","frus1961-63v10-12mSupp","frus1964-68v32","frus1969-76ve10","frus1969-76ve11p1","frus1977-80v23","frus1977-80v24"]
raw = {v: open(V+v+".xml", encoding="utf-8", errors="replace").read() for v in nine}
text = {v: html.unescape(re.sub(r"<[^>]+>", " ", r)) for v, r in raw.items()}
def cnt(rx, src, flags=re.I): return sum(len(re.findall(rx, src[v], flags)) for v in nine)
for claim, rx in [("Disapprove 93","disapprove"),("Options Paper 18","options paper"),("Decision Memorandum 43","decision memorandum"),("Action Memorandum 103","action memorandum"),("Recommendation 1,537","recommendation"),("Approve 2,129","approve"),("Interests Section 77","interests section"),("Mexican Government 124","mexican government"),("Presidential Directive 20","presidential directive"),("Guantanamo 441 (no accent)","guantanamo"),("Vaky 525","vaky"),("Castro (whole nine)","castro")]:
    print(f"{claim:30s} text-ci={cnt(rx, text):6d}  raw-ci={cnt(rx, raw):6d}")
ms = "frus1961-63v10-12mSupp"
print("mSupp Castro raw-cs:", len(re.findall("Castro", raw[ms])), "text-ci:", len(re.findall("castro", text[ms], re.I)), "memo 1,877")
print("mSupp 'memorandum of conversation' ci text:", len(re.findall("memorandum of conversation", text[ms], re.I)), "raw-ci:", len(re.findall("memorandum of conversation", raw[ms], re.I)), "memo 232")
print("mSupp 'memcon' ci:", len(re.findall("memcon", text[ms], re.I)))
