import re, json, sqlite3
RUN="/Users/jbotts/frus-analysis/c3s/runs/s5/"
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
db=sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
ov=open(RUN+"overview.md").read()
man=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
def find_vol(obj, vid):
    stack=[obj]
    while stack:
        o=stack.pop()
        if isinstance(o,dict):
            if any(v==vid for v in o.values() if isinstance(v,str)): return o
            stack.extend(o.values())
        elif isinstance(o,list): stack.extend(o)
    return None
def vol_title(vid):
    o=find_vol(man,vid)
    if not o: return None
    for k in ("title","volumeTitle","name","fullTitle"):
        if k in o and isinstance(o[k],str): return o[k]
    return str({k:v for k,v in o.items() if isinstance(v,str)})[:200]
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def segs(qt): return [s for s in re.split(r'\[\.\.\.\]|\.\.\.|…', qt) if norm(s)]
def doc_text(v,d):
    r=db.execute("SELECT header, COALESCE(dateline,''), COALESCE(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    return None if r is None else "".join(r)
def check(qt, text):
    t=norm(text); pos=0
    for s in segs(qt):
        ns=norm(s); i=t.find(ns,pos)
        if i<0: return False
        pos=i+len(ns)
    return True
def dash(s): return re.sub(r'[–—-]','-',s).replace('  ',' ').strip()
cit_re=re.compile(r'\*([^*]+)\*, Document (\d+) \((https://history\.state\.gov/historicaldocuments/([^/)]+)/(d\d+))\)')
cits=[(m.start(), m.group(1), m.group(2), m.group(4), m.group(5)) for m in cit_re.finditer(ov)]
print("citations in overview:", len(cits), "distinct pairs:", len({(c[3],c[4]) for c in cits}))
# citation resolution: title vs manifest, Document N vs document_number
print("\n== CITATION RESOLUTION ==")
bad=0
for pos,title,num,vol,doc in sorted(set((0,c[1],c[2],c[3],c[4]) for c in cits), key=lambda x:(x[3],int(x[4][1:]))):
    mt=vol_title(vol)
    r=db.execute("SELECT document_number, substr(header,1,80), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(vol,doc)).fetchone()
    ok_t = (mt is not None and dash(mt)==dash(title))
    ok_n = (r is not None and str(r[0])==num)
    if not (ok_t and ok_n): bad+=1
    print(f"{vol}/{doc}: title_ok={ok_t} number_ok={ok_n} doc_number={r[0] if r else None} fm/ed={(r[2],r[3]) if r else None} | printed='{title}' | manifest='{mt}' | header='{r[1] if r else None}'")
print("citation problems:", bad)
# memo trace Q table
Q={ "Q1":("frus1947v05","d23"),"Q2":("frus1949v08","d576"),"Q3":("frus1981-88v01","d247"),"Q4":("frus1944v06","d269"),"Q5":("frus1922v01","d864"),"Q6":("frus1950v06","d802"),"Q7":("frus1922v01","d841"),"Q8":("frus1958-60v01","d135"),"Q9":("frus1964-68v05","d258"),"Q10":("frus1964-68v05","d258"),"Q11":("frus1981-88v41","d251"),"Q12":("frus1949v06","d330"),"Q13":("frus1949v06","d330"),"Q14":("frus1950v05","d289"),"Q15":("frus1961-63v22","d252"),"Q16":("frus1969-76ve09p2","d155"),"Q17":("frus1977-80v24","d337"),"Q18":("frus1977-80v03","d248"),"Q19":("frus1893","d628"),"Q20":("frus1921v01","d275"),"Q21":("frus1981-88v01","d264"),"Q22":("frus1912","d1502")}
memo=open(RUN+"memo.md").read()
qtext={}
for m in re.finditer(r'^\| (Q\d+) \| (\S+) \| (.+?) \| `SELECT', memo, re.M):
    qtext[m.group(1)]=(m.group(2), m.group(3).strip())
# overview quotations (curly double quotes)
quotes=[(m.start(), m.end(), m.group(1)) for m in re.finditer(r'“([^”]+)”', ov)]
print("\n== OVERVIEW QUOTATIONS (curly double quotes) ==", len(quotes))
nfab=nmis=nver=0
for qs,qe,qt in quotes:
    nxt=[c for c in cits if c[0]>=qe]
    cit=nxt[0] if nxt else None
    pair=(cit[3],cit[4]) if cit else None
    # memo trace row for this text
    qid=next((k for k,(p,t) in qtext.items() if norm(t)==norm(qt)), None)
    mpair=Q.get(qid) if qid else None
    text=doc_text(*pair) if pair else None
    found_cited = check(qt,text) if text else False
    found_memo = (check(qt,doc_text(*mpair)) if mpair else None)
    status = "VERIFIED" if found_cited and (mpair is None or mpair==pair) else ("MISCITED" if (found_memo or (not found_cited and mpair and mpair!=pair)) else "FABRICATION")
    if not found_cited and mpair and mpair!=pair and found_memo: status="MISCITED"
    if not found_cited and not found_memo: status="FABRICATION"
    if status=="VERIFIED": nver+=1
    elif status=="MISCITED": nmis+=1
    else: nfab+=1
    print(f"[{status}] {qid} memo_pair={mpair} overview_cites={pair} found_in_cited={found_cited} | {qt[:90]}")
print("overview: verified", nver, "miscited", nmis, "fabricated", nfab)
# single-quoted terms in overview, for the record
print("\nsingle-quoted strings in overview:", re.findall(r'‘([^’]+)’', ov))
print("straight double quotes in overview:", re.findall(r'"([^"]+)"', ov))
# excerpts in collection
coll=json.load(open(RUN+"collection.fruscollection"))
print("\n== COLLECTION EXCERPTS ==")
ev=ef=0
for e in coll["entries"]:
    if e["kind"]!="excerpt": continue
    pair=(e["volumeId"],e["documentId"]); ok=check(e["text"],doc_text(*pair))
    qid=next((k for k,(p,t) in qtext.items() if norm(t)==norm(e["text"])), None)
    same = (Q.get(qid)==pair) if qid else None
    ev+=ok; ef+=(not ok)
    print(f"[{'VERIFIED' if ok else 'FABRICATION'}] {qid} memo_pair_matches={same} {pair[0]}/{pair[1]} | {e['text'][:90]}")
print("excerpts: verified", ev, "fabricated", ef)
# overview quotes as set vs excerpts as set
oq={norm(q[2]) for q in quotes}; ex={norm(e["text"]) for e in coll["entries"] if e["kind"]=="excerpt"}
print("overview quote texts == excerpt texts:", oq==ex, "| only in overview:", len(oq-ex), "only in excerpts:", len(ex-oq))
