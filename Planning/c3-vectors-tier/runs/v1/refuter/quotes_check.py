# Refuter: the guide's quotation check over every quotation in overview.md and every excerpt in the collection,
# against header||dateline||source_note||body_text of the EXACT (volume_id, document_id) cited.
import sqlite3, re, json
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c=sqlite3.connect(DB,uri=True)
RUN="/Users/jbotts/frus-analysis/c3v/runs/v1/"
def norm(s): return re.sub(r"[^a-z0-9]","",s.lower())
cache={}
def doc(v,d):
    if (v,d) not in cache:
        r=c.execute("SELECT header, dateline, source_note, body_text, is_front_matter, is_editorial_note, document_number FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        cache[(v,d)]=r
    return cache[(v,d)]
def check(q,v,d):
    r=doc(v,d)
    if r is None: return False,"NO SUCH ROW"
    hay=norm((r[0] or "")+(r[1] or "")+(r[2] or "")+(r[3] or ""))
    segs=[norm(s) for s in re.split(r"…|\.\.\.|\[\.\.\.\]",q)]
    segs=[s for s in segs if s]
    pos=0
    for s in segs:
        i=hay.find(s,pos)
        if i<0: return False,"segment not found: %r"%s[:60]
        pos=i+len(s)
    return True,"ok (%d segment%s)"%(len(segs),"" if len(segs)==1 else "s")
# --- overview quotations, in reading order, with the pair each is credited to ---
ov=open(RUN+"overview.md").read()
# every “…” string and every block-quote line
inline=re.findall(r"“([^”]+)”",ov)
print("“…” strings in overview:",len(inline))
# the mapping: pair from the citation beside the quotation, else from the memo's trace table (section 9) -> section 4 Q-ids
M={
 "almost contiguous to the United States":("frus1874","d552"),
 "a large and lucrative market":("frus1874","d552"),
 "the commerce, trade, and business of our people":("frus1898","ch83"),
 "a constant menace to our peace":("frus1898","ch83"),
 "of great strategic importance":("frus1950v02","d440"),
 "a domestic, political problem":("frus1961-63v11","d21"),   # memo trace -> Q26
 "strategic weapons":("frus1969-76ve10","d205"),
 "It presents no direct threat to us":("frus1977-80v01","d129"),
 "perpetual solicitude":("frus1874","d552"),                  # memo trace -> Q03
 "It is almost contiguous to the United States.":("frus1874","d552"),
 "our great commerce with Cuba has thus been practically destroyed":("frus1898","d498"),
 "The present condition of affairs in Cuba is a constant menace to our peace, and entails upon this Government an enormous expense.":("frus1898","ch83"),
 "nor in any manner authorize or permit any foreign power or powers to obtain, by colonization or for military or naval purposes or otherwise, lodgment in or control over any portion of said island":("frus1902","d273"),
 "Cuba’s greatest aid to the United States in the prosecution of the war would be economic rather than military":("frus1918","d333"),
 "the stipulations of that agreement with regard to the naval station of Guantánamo shall continue in effect":("frus1934v05","d170"),
 "economic and defense reasons":("frus1941v07","d134"),       # memo trace -> Q10
 "our interest in the Cuban situation for economic and defense reasons is such":("frus1941v07","d134"),
 "we could, by manipulation of tariff or quota affecting sugar, plunge the entire island into poverty":("frus1948v09","d420"),
 "Cuba, lying 90 miles to the south of Key West, Florida, is of great strategic importance to the US both because of its location with respect to the Panama Canal and the sea lanes of the Caribbean and because in two wars it has been the major and most readily-expandible source of sugar":("frus1950v02","d440"),
 "retaliatory instruments":("frus1958-60v06","d362"),         # memo trace -> Q13
 "one Rubicon":("frus1958-60v06","d567"),                     # memo trace -> Q14
 "our retaliatory instruments, such as GATT and the sugar quota, are likely to be used":("frus1958-60v06","d362"),
 "Amendment of the preferential sugar quota act to provide for a reduction from 20 to 25 per cent of Cuba’s quota.":("frus1958-60v06","d532"),
 "Since we have crossed one Rubicon with our sugar and oil actions":("frus1958-60v06","d567"),
 "intolerable and not acceptable":("frus1961-63v11","d18"),   # memo trace -> Q18
 "doesn’t mean that much":("frus1961-63v11","d21"),           # memo trace -> Q16
 "this kind of a base is intolerable and not acceptable":("frus1961-63v11","d18"),
 "I don’t think there is a military problem here.":("frus1961-63v11","d21"),
 "Geography doesn’t mean that much.":("frus1961-63v11","d21"),
 "subsidiary and lesser":("frus1969-76ve10","d205"),          # memo trace -> Q20
 "We have a vital interest: 1. In preventing the introduction into Cuba of strategic weapons.":("frus1969-76ve10","d205"),
 "to gain access to U.S. markets and technology to stimulate its economy":("frus1977-80v23","d18"),
 "It presents no direct threat to us.":("frus1977-80v01","d129"),
}
TERMS={"Department of State","national security","menace"}  # search terms / vocabulary, not document quotations
nq=0; ok=0; bad=[]
for i,q in enumerate(inline,1):
    if q in TERMS:
        print("%2d. [term, not a quotation] “%s”"%(i,q)); continue
    if q not in M:
        print("%2d. UNMAPPED “%s”"%(i,q[:80])); bad.append((q,None,"unmapped")); nq+=1; continue
    v,d=M[q]; r,msg=check(q,v,d); nq+=1; ok+=r
    print("%2d. %s  %s/%s  “%s”  -> %s"%(i,"PASS" if r else "FAIL",v,d,q[:70],msg))
    if not r: bad.append((q,(v,d),msg))
print("overview quotations checked:",nq,"passed:",ok,"failed:",len(bad))
# the same quotation elsewhere in the corpus? (for a failed one, is it found under another pair)
# --- collection excerpts ---
col=json.load(open(RUN+"collection.fruscollection"))
ex=[e for e in col["entries"] if e["kind"]=="excerpt"]
eok=0; ebad=[]
for i,e in enumerate(ex,1):
    r,msg=check(e["text"],e["volumeId"],e["documentId"]); eok+=r
    print("X%02d %s %s/%s “%s” -> %s"%(i,"PASS" if r else "FAIL",e["volumeId"],e["documentId"],e["text"][:60],msg))
    if not r: ebad.append((e["text"],(e["volumeId"],e["documentId"]),msg))
print("excerpts checked:",len(ex),"passed:",eok,"failed:",len(ebad))
# single-quoted passages in the collection's notes and prose (not excerpts; reported for completeness)
for e in col["entries"]:
    txts=[e.get("text","")]+e.get("notes",[])
    for t in txts:
        for q in re.findall(r"'([^']{6,})'",t):
            if e["kind"] in ("document",):
                r,msg=check(q,e["volumeId"],e["documentId"]); print("note-quote %s %s/%s '%s' -> %s"%("PASS" if r else "FAIL",e["volumeId"],e["documentId"],q,msg))
            else:
                print("prose-quote (no pair on the entry) '%s'"%q)
# --- edition citations: do the printed titles and document numbers resolve to the pairs? ---
man=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
vols=man["volumes"] if isinstance(man,dict) and "volumes" in man else man
title={}
for x in (vols if isinstance(vols,list) else vols.values()):
    vid=x.get("id") or x.get("volumeId") or x.get("volume_id")
    title[vid]=x.get("title") or x.get("fullTitle") or x.get("name")
cites=re.findall(r"\(((?:Papers Relating to the )?Foreign Relations of the United States[^()]*?), (https://history\.state\.gov/historicaldocuments/([^/]+)/([^\s)]+))\)",ov)
cites+= [(m[0],m[1],m[2],m[3]) for m in re.findall(r"— ((?:Papers Relating to the )?Foreign Relations of the United States[^\n]*?), (https://history\.state\.gov/historicaldocuments/([^/]+)/([^\s)]+))",ov)]
seen=set()
print("\nEDITION CITATIONS (printed title / document number vs the URL's pair and the manifest title):")
for printed,url,v,d in cites:
    if (printed,v,d) in seen: continue
    seen.add((printed,v,d))
    r=doc(v,d)
    mt=title.get(v)
    m=re.search(r"Document (\d+)$",printed)
    dn=m.group(1) if m else None
    ok_vol = mt is not None and (printed.startswith(mt) or mt in printed)
    ok_doc = (dn is None) or (d=="d"+dn)
    print(" %s %s/%s | printed=%r | manifest title=%r | docnum in index=%r | title-match=%s doc-match=%s"%("OK " if (ok_vol and ok_doc and r) else "?? ",v,d,printed,mt,r[6] if r else None,ok_vol,ok_doc))
