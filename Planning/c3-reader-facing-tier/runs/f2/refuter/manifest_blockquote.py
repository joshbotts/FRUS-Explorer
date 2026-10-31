import json,re,sqlite3
R="/Applications/FRUS Explorer.app/Contents/Resources/"; RUN="/Users/jbotts/frus-analysis/c3f/runs/f2/"
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
c=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
scope={l.split("\t")[0]:l.split("\t")[1] for l in open(RUN+"scope_volumes.tsv")}
EA={v for v,k in scope.items() if k=="EA"}; PD={v for v,k in scope.items() if k=="PD"}
M=json.load(open(R+"manifest.json"))
print("manifest: list of",len(M),"| sample keys:",list(M[0].keys()))
tk=[k for k in M[0] if "title" in k.lower()]; print("title-ish keys:",tk)
def vid(v): return v.get("id") or v.get("volumeId") or v.get("volume_id")
rx=re.compile(r"China|Japan|Korea|East Asia|Southeast Asia|Vietnam|Indochina|Philippine|Indonesia|Pacific|Far East|Laos|Cambodia|Northeast Asia|Burma|Thailand")
def title(v): return " ".join(str(v.get(k,"")) for k in tk)
ea={vid(v) for v in M if rx.search(title(v))}; pd_={vid(v) for v in M if "Public Diplomacy" in title(v)}
print("regex EA:",len(ea),"| PD:",len(pd_),"| union:",len(ea|pd_))
print("  EA == scope EA:",ea==EA,"| mine-scope:",sorted(ea-EA),"| scope-mine:",sorted(EA-ea))
print("  PD == scope PD:",pd_==PD,"| sym diff:",sorted(pd_^PD))
print("  Ed2 in scope:",[v for v in scope if v.endswith("Ed2")],"| Ed2 in manifest:",[vid(v) for v in M if str(vid(v)).endswith("Ed2")])
indexed={r[0] for r in c.execute("SELECT DISTINCT volume_id FROM document_cache")}
print("  scope volumes present in index:",sum(v in indexed for v in scope),"of",len(scope),"| manifest ids in index:",sum(vid(v) in indexed for v in M),"of",len(M))
# '1917–1972, Volume VI' ambiguity: any other manifest title with 1917–1972 and Volume VI/VII/VIII?
for roman in ["Volume VI,","Volume VII,","Volume VIII,"]:
    hits=[vid(v) for v in M if "1917–1972" in title(v) and roman in title(v)]
    print("  titles with 1917–1972 and",roman,hits)
# latest date of frus1977-80v30 and the WWI PD volume title
for v in M:
    if vid(v) in ("frus1977-80v30","frus1917-72PubDip"): print("  ",vid(v),"|",title(v)[:120],"|",{k:v[k] for k in v if "date" in k.lower() or "year" in k.lower() or "latest" in k.lower()})
print("\n== block quote and note phrases ==")
def norm(s): return re.sub(r"[^a-z0-9]","",s.lower())
def chk(pair,q):
    r=c.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?",pair).fetchone()
    full=norm("".join(x or "" for x in r)); b=norm(r[3] or "")
    print(pair,repr(q[:70]),"full:",full.find(norm(q)),"body:",b.find(norm(q)))
chk(("frus1955-57v09","d190"),"In the Far East USIA was forced to deal with mixed emotions regarding the use of atomic weapons against Asiatic peoples, and to counter communist propaganda designed to stir up race hatred.")
chk(("frus1952-54v12p2","d352"),"free Asian solidarity")
chk(("frus1917-72PubDipv08","d31"),"modesty, mutuality and multi-lateralism")
for pair in [("frus1964-68v29p2","d46"),("frus1917-72PubDipv06","d127"),("frus1961-63v03","d308")]:
    b=c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",pair).fetchone()[0]
    i=b.find("Reischauer"); print(pair,"'Reischauer' at",i,"|",b[-160:].replace("\n"," ") if pair[1]=="d46" else "")
    if pair[1]=="d308": print("   d308 mentions 'Far East' at",b.find("Far East"),"; 'Asia' at",b.find("Asia"))
