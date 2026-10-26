# Every double-quoted span in overview.md must be (a) a substring of a quotation in quotes.json that is itself an exact
# substring of its document's body_text, or (b) on the allowlist of search terms / bundled labels / titles (not document quotations).
import re, json, sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
Q=json.load(open("quotes.json"))
ver=[]
for f,v,d,s in Q:
    b=con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,d)).fetchone()
    assert b and s in b[0], (v,d,s); ver.append((v,d,s))
ALLOW={"political affairs","government","Independence. Recognition.","Rebellion. Coups.","By force","by force","de facto","revolution","coup d'état","junta","Department of State","Legal Adviser","recognize/recognition","continuity of diplomatic relations","recognize","Recognizing governments that came to power by force — Latin America","8xx.00","8xx.01","new government","military government","military regime","came to power by force","provisional government"}
t=open("overview.md",encoding="utf-8").read()
spans=re.findall(r'"([^"]+)"',t)
bad=[]; used=set()
for s in spans:
    if s in ALLOW: continue
    hit=[(v,d) for v,d,x in ver if s in x]
    if hit: used.update(hit)
    else: bad.append(s)
print("quoted spans",len(spans),"unverified",len(bad)); [print("  BAD:",b[:120]) for b in bad]
print("documents quoted in overview:",len(used))
json.dump(sorted(used),open("raw/overview_quoted_docs.json","w"))
