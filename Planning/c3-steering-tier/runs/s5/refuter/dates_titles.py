import json, re, sqlite3
RUN="/Users/jbotts/frus-analysis/c3s/runs/s5/"
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
ov=open(RUN+"overview.md").read()
man=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
print("manifest top keys:", list(man.keys()) if isinstance(man,dict) else type(man))
vols = man.get("volumes") if isinstance(man,dict) else man
print("manifest volume sample keys:", list(vols[0].keys()) if isinstance(vols,list) else list(vols.items())[0])
def norm_ws(s): return re.sub(r'\s+',' ', re.sub(r'[–—]','-', s)).strip()
titles={}
if isinstance(vols,list):
    for v in vols:
        vid=v.get("id") or v.get("volumeId") or v.get("volume_id")
        titles[vid]=v.get("title") or v.get("fullTitle") or v.get("name")
cit_re=re.compile(r'\*([^*]+)\*, Document (\d+) \(https://history\.state\.gov/historicaldocuments/([^/)]+)/(d\d+)\)')
bad=0; seen=set()
for m in cit_re.finditer(ov):
    title,num,vol,doc=m.groups()
    if (vol,doc,title) in seen: continue
    seen.add((vol,doc,title))
    mt=titles.get(vol)
    ok = mt is not None and norm_ws(mt)==norm_ws(title)
    if not ok: bad+=1; print("TITLE MISMATCH", vol, doc, "| printed:", title, "| manifest:", mt)
print("distinct (vol,doc,title) citations:", len(seen), "title mismatches after whitespace collapse:", bad)
print("\n== dates, datelines, headers of the 38 cited pairs ==")
pairs=json.load(open(RUN+"refuter/cited_pairs.json"))["cited"]
for v,d in pairs:
    r=db.execute("SELECT dd.date_iso, c.dateline, substr(c.header,1,95) FROM document_cache c LEFT JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?",(v,d)).fetchone()
    print(f"{v}/{d}: {r[0]} | {r[1]!r:45.45} | {r[2]}")
# wider windows for the two marginal decision-coded sample documents, and the three attribution checks
def win(v,d,pat,w=450,maxn=2):
    t=" ".join(db.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0].split())
    out=[]
    for m in list(re.finditer(pat,t,re.I))[:maxn]:
        out.append(t[max(0,m.start()-w):m.end()+w])
    return out
for v,d in [("frus1958-60v15","d411"),("frus1964-68v02","d265")]:
    print(f"\n== window {v}/{d} ==")
    for s in win(v,d,r'corrupt'): print("  ...", s, "...")
print("\n== attribution checks ==")
for v,d,pat in [("frus1949v08","d576",r'corrupt as it is'),("frus1912","d1502",r'arbitrary and corrupt'),("frus1977-80v03","d248",r'can bribe foreign'),("frus1947v05","d23",r'experts|public administration'),("frus1964-68v05","d301",r'corruption'),("frus1961-63v01","d298",r'corrupt'),("frus1969-76v08","d191",r'corrupt'),("frus1961-63v20","d422",r'corrupt'),("frus1964-68v32","d8",r'corrupt|graft'),("frus1952-54v12p2","d324",r'corrupt|stolen|fraud'),("frus1955-57v22","d7",r'corrupt'),("frus1958-60v01","d156",r'corrupt'),("frus1958-60v01","d160",r'corrupt'),("frus1950v03","d728",r'corrupt'),("frus1977-80v03","d35",r'brib|illicit'),("frus1981-88v01","d247",r'liabilit'),("frus1981-88v01","d264",r'as in Manila')]:
    print(f"\n-- {v}/{d} --")
    for s in win(v,d,pat,260,1): print("  ...", s, "...")
