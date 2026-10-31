import json,re
R="/Applications/FRUS Explorer.app/Contents/Resources/"; RUN="/Users/jbotts/frus-analysis/c3f/runs/f2/"
scope={l.split("\t")[0]:l.split("\t")[1] for l in open(RUN+"scope_volumes.tsv")}
EA={v for v,k in scope.items() if k=="EA"}; PD={v for v,k in scope.items() if k=="PD"}
M=json.load(open(R+"manifest.json"))
T={v["volumeId"]:" ".join(v["title"].split()) for v in M}
rx=re.compile(r"China|Japan|Korea|East Asia|Southeast Asia|Vietnam|Indochina|Philippine|Indonesia|Pacific|Far East|Laos|Cambodia|Northeast Asia|Burma|Thailand")
ea={k for k,t in T.items() if rx.search(t)}; pd_={k for k,t in T.items() if "Public Diplomacy" in t}
print("whitespace-collapsed titles: regex EA:",len(ea),"| PD:",len(pd_),"| EA minus PD:",len(ea-pd_),"| union:",len(ea|pd_))
print("  EA == scope EA:",ea==EA,"| mine-scope:",sorted(ea-EA),"| scope-mine:",sorted(EA-ea))
print("  PD == scope PD:",pd_==PD,"| sym diff:",sorted(pd_^PD))
print("  EA∩PD:",sorted(ea&pd_))
for roman in ["Volume VI,","Volume VII,","Volume VIII,"]:
    print("  titles with 1917–1972 and",roman,[k for k,t in T.items() if "1917–1972" in t and roman in t])
print("  frus1955-57v22:",T["frus1955-57v22"])
print("  Ed2 ids in manifest:",[k for k in T if k.endswith("Ed2")],"| any in scope:",[k for k in scope if k.endswith("Ed2")])
