import re,json,sqlite3,sys
RUN="/Users/jbotts/frus-analysis/c3f/runs/f6/"
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
man=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
title_of={m['volumeId']:m['title'] for m in man}
ov=open(RUN+"overview.md",encoding="utf8").read()
body,cited=ov.split("## Documents cited")
# --- Documents cited list -> pairs
rom={'I':1,'II':2,'III':3,'IV':4,'V':5,'VI':6,'VII':7,'VIII':8,'IX':9,'X':10,'XI':11,'XII':12,'XIII':13,'XIV':14,'XV':15,'XVI':16,'XVII':17,'XVIII':18,'XIX':19,'XX':20,'XXI':21,'XXII':22,'XXIII':23,'XXIV':24,'XXV':25,'XXVI':26,'XXVII':27,'XXVIII':28,'XXIX':29,'XXX':30,'XXXI':31,'XXXII':32,'XXXIII':33,'XXXIV':34,'XXXV':35,'XXXVI':36,'XXXVII':37,'XXXVIII':38}
listmap={}  # (volkey, part, docnum) -> (vol, doc, years)
cited_pairs=[]
for line in cited.strip().splitlines():
    m=re.match(r'\s*\d+\.\s+Foreign Relations of the United States, (\d{4}(?:–\d{4})?), (.*?Volume ([IVXLE–\d]+)(?:, Part (\d))?.*?), Document (\d+)\. https://history\.state\.gov/historicaldocuments/([^/]+)/(d\d+)',line)
    if not m:
        print("UNPARSED LIST LINE:",line); continue
    years,mid,vol,part,dn,vid,did=m.groups()
    cited_pairs.append((vid,did))
    listmap[(vol,part or '',dn)]=(vid,did,years)
    # check manifest: volume id exists and the document number matches the index row
    r=con.execute("SELECT document_number,is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(vid,did)).fetchone()
    if r is None: print("LIST PAIR NOT IN INDEX:",vid,did)
    elif str(r[0])!=dn: print("LIST DOC NUMBER MISMATCH:",vid,did,"index says",r[0],"list says",dn)
    if vid not in title_of: print("LIST VOLUME NOT IN MANIFEST:",vid)
print("Documents cited list entries:",len(cited_pairs),"distinct:",len(set(cited_pairs)))
# --- short citations in the body -> pairs via list; check the year lies in the subseries range
def resolve(cit):
    m=re.match(r'(\d{4}), (?:Public Diplomacy, )?Volume ([IVXLE–\d]+)(?:, Part (\d))?, Document (\d+)',cit)
    if not m: return None,"unparsed"
    y,vol,part,dn=m.groups(); part=part or ''
    k=(vol,part,dn)
    if k not in listmap: return None,"not in list"
    vid,did,years=listmap[k]
    y0=int(years[:4]); y1=int(years[-4:])
    # manifest subseries years for this volume id
    mm=[x for x in man if x['volumeId']==vid][0]
    ok = y0<=int(y)<=y1
    return (vid,did),("year in list range" if ok else f"YEAR {y} OUTSIDE {years}")
# --- quotation check
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def segcheck(q,text):
    segs=[s for s in re.split(r'…|\.\.\.|\[\.\.\.\]',q) if norm(s)]
    pos=0
    for s in segs:
        i=text.find(norm(s),pos)
        if i<0: return False
        pos=i+len(norm(s))
    return True
rowtext={}
def doctext(v,d):
    if (v,d) not in rowtext:
        r=con.execute("SELECT header,ifnull(dateline,''),ifnull(source_note,''),body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        rowtext[(v,d)]=norm(''.join(r)) if r else None
    return rowtext[(v,d)]
# find each quotation and the citation that follows it (nearest parenthetical citation after the quote, in the same sentence/paragraph)
quotes=[]
for para in body.split("\n"):
    for m in re.finditer(r'["“]([^"”]{2,}?)["”]',para):
        q=m.group(1)
        after=para[m.end():]
        c=re.search(r'\((\d{4}, (?:Public Diplomacy, )?Volume [^)]*?Document \d+)\)',after)
        before=para[:m.start()]
        cb=list(re.finditer(r'\((\d{4}, (?:Public Diplomacy, )?Volume [^)]*?Document \d+)\)',before))
        quotes.append((q,c.group(1) if c else None,cb[-1].group(1) if cb else None,para[:60]))
print("\nQuotations in overview body:",len(quotes))
fab=0;mis=0;ok=0;nodoc=0
for q,cafter,cbefore,ctx in quotes:
    cit=cafter
    # a quotation whose following sentence carries no citation: fall back to the one before (same paragraph)
    tag=''
    if cit is None and cbefore: cit=cbefore; tag=' (citation taken from before the quote)'
    if cit is None:
        print(f"  NO CITATION  | {q[:80]!r} | para: {ctx!r}"); nodoc+=1; continue
    pair,how=resolve(cit)
    if pair is None:
        print(f"  UNRESOLVED   | {q[:80]!r} | ({cit}) {how}"); mis+=1; continue
    t=doctext(*pair)
    found=segcheck(q,t)
    # where else in the 27 cited does it appear?
    others=[p for p in set(cited_pairs) if p!=pair and segcheck(q,doctext(*p))]
    verdict="FOUND" if found else ("MIS-CITED(in other cited doc)" if others else "FABRICATION")
    if found: ok+=1
    elif others: mis+=1
    else: fab+=1
    print(f"  {verdict:12s} | {q[:80]!r} | ({cit}) -> {pair[0]}/{pair[1]} [{how}]{tag}" + (f" others={others}" if others and not found else ""))
print(f"\nSUMMARY overview quotations: found={ok} fabrication={fab} miscited={mis} nocitation={nodoc} total={len(quotes)}")
# --- collection excerpts
col=json.load(open(RUN+"collection.fruscollection"))
ex=[e for e in col['entries'] if e['kind']=='excerpt']
eok=0
for e in ex:
    t=doctext(e['volumeId'],e['documentId'])
    f=segcheck(e['text'],t); eok+=f
    if not f: print("  EXCERPT NOT IN ROW:",e['volumeId'],e['documentId'],e['text'][:80])
print(f"collection excerpts: {eok} of {len(ex)} found in their row")
# --- collection membership of cited docs
coldocs={(e['volumeId'],e['documentId']) for e in col['entries'] if e['kind']=='document'}
print("cited pairs in collection:",sum(1 for p in set(cited_pairs) if p in coldocs),"of",len(set(cited_pairs)),"; not in:",[p for p in set(cited_pairs) if p not in coldocs],"; collection docs not cited:",[p for p in coldocs if p not in set(cited_pairs)])
# --- dates and flags of the 27
print("\npair | date_iso | document_number | fm | en")
for v,d in cited_pairs:
    r=con.execute("SELECT dd.date_iso,c.document_number,c.is_front_matter,c.is_editorial_note FROM document_cache c LEFT JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?",(v,d)).fetchone()
    print(v,d,*r)
json.dump(sorted(set(cited_pairs)),open("cited_pairs.json","w"))
