import re, os, html
V = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes/"
nine = ["frus1961-63v10","frus1961-63v11","frus1961-63v12","frus1961-63v10-12mSupp","frus1964-68v32","frus1969-76ve10","frus1969-76ve11p1","frus1977-80v23","frus1977-80v24"]
raw = {v: open(V+v+".xml", encoding="utf-8", errors="replace").read() for v in nine}
text = {v: html.unescape(re.sub(r"<[^>]+>", " ", r)) for v, r in raw.items()}
terms = {  # memo figure -> (regex, case-insensitive?)
 "Attwood 74": (r"Attwood", False), "Lechuga 83": (r"Lechuga", False), "Lisa Howard 21": (r"Lisa Howard", False),
 "Eagleburger 44": (r"Eagleburger", False), "Interests Section 77": (r"Interests Section", False), "Tarnoff 92": (r"Tarnoff", False),
 "Angola 305": (r"Angola", False), "Vaky 525": (r"Vaky", False),
 "normaliz* 224": (r"normaliz", True), "dialogue 385": (r"dialogue", True), "accommodation 168": (r"accommodation", True),
 "rapprochement 75": (r"rapprochement", True), "emissary 78": (r"emissary", True), "intermediary 31": (r"intermediary", True),
 "feeler 17": (r"feeler", True), "modus vivendi 25": (r"modus vivendi", True), "precondition 34": (r"precondition", True),
 "quid pro quo 32": (r"quid pro quo", True), "bilateral talk* 17": (r"bilateral talk", True), "secret talk* 7": (r"secret talk", True),
 "Swiss 94": (r"Swiss", False), "Czech 106": (r"Czech", False), "Mexican Government 124": (r"Mexican Government", False),
 "hijack* 232": (r"hijack", True), "Guantanamo 441": (r"Guant[aá]namo", True),
 "Disapprove 93": (r"Disapprove", False), "Options Paper 18": (r"Options Paper", False), "Decision Memorandum 43": (r"Decision Memorandum", False),
 "Action Memorandum 103": (r"Action Memorandum", False), "Recommendation 1,537": (r"Recommendation", False), "Approve 2,129": (r"Approve", False),
 "NSSM 258": (r"NSSM", False), "NSDM 234": (r"NSDM", False), "PRM/NSC 8": (r"PRM/NSC", False), "Presidential Directive 20": (r"Presidential Directive", False),
 "back channel 2": (r"back channel", True), "backchannel 23": (r"backchannel", True),
}
print(f"{'claim':28s} {'text(ci/cs as stated)':>10s} {'raw-xml':>8s}   per-volume (text)")
for claim, (rx, ci) in terms.items():
    flags = re.I if ci else 0
    per = {v: len(re.findall(rx, text[v], flags)) for v in nine}
    rawc = sum(len(re.findall(rx, raw[v], flags)) for v in nine)
    print(f"{claim:28s} {sum(per.values()):10d} {rawc:8d}   {per}")
# mSupp-specific
ms = text["frus1961-63v10-12mSupp"]
print("\nmSupp: Lechuga", len(re.findall("Lechuga", ms)), "rapprochement", len(re.findall("rapprochement", ms, re.I)), "Castro", len(re.findall("Castro", ms)), "Memorandum of Conversation", len(re.findall("Memorandum of Conversation", ms)))
print("precondition in v23:", len(re.findall("precondition", text["frus1977-80v23"], re.I)))
# Attwood in Africa volumes
for v in ["frus1961-63v21","frus1964-68v18","frus1964-68v20","frus1964-68v23","frus1964-68v24"]:
    p = V+v+".xml"
    print(v, "Attwood:", len(re.findall("Attwood", open(p, encoding="utf-8", errors="replace").read())) if os.path.exists(p) else "NO FILE")
