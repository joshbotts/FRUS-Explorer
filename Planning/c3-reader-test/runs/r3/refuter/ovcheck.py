import json, re, sqlite3
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RUN="/Users/jbotts/frus-analysis/c3/runs/r3"
con=sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def segments(q):
    return [norm(p) for p in re.split(r'\[\.\.\.\]|\.\.\.|…', q) if norm(p)]
def rowtext(v,d):
    r=con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    return None if r is None else ''.join(x or '' for x in r)
def check(q,v,d):
    t=rowtext(v,d)
    if t is None: return ('NO_ROW',None)
    nt=norm(t); pos=0; first=None
    for seg in segments(q):
        i=nt.find(seg,pos)
        if i<0: return ('FAIL',seg[:50])
        if first is None: first=i
        pos=i+len(seg)
    return ('OK',first)
quotes=json.load(open(f"{RUN}/refuter/overview_quotes.json"))
# memo trace pairs for the 18 document quotations (from memo section 7)
trace={1:('frus1900','d530'),2:('frus1913','d7'),3:('frus1921v02','d344'),12:('frus1911','d353'),13:('frus1917','d379'),
14:('frus1920v03','d199'),15:('frus1921v02','d349'),16:('frus1926v02','d476'),17:('frus1930v01','d375'),18:('frus1931v02','d208'),
19:('frus1933v05','d508'),20:('frus1933v05','d430'),21:('frus1934v05','d75'),22:('frus1944v07','d403'),23:('frus1948v09','d7'),
24:('frus1961-63v12','d423'),25:('frus1964-68v31','d152'),26:('frus1969-76ve08','d6')}
print("== 18 overview document quotations: memo-trace pair vs overview URL pair, then the check against the memo's pair ==")
nfail=0
for i,(pos,q,urlpair) in enumerate(quotes,1):
    if i in trace:
        v,d=trace[i]
        same = (tuple(urlpair)==(v,d)) if urlpair else False
        st,off=check(q,v,d)
        if st!='OK': nfail+=1
        print(f"{i:2d}. memo={v}/{d} urlpair_same={same} {st} off={off} :: {q[:70]}")
print("failures:",nfail)
# the heading label (27) against frus1920v03/ch23 header
print("\n== heading label check ==")
r=con.execute("SELECT header FROM document_cache WHERE volume_id='frus1920v03' AND document_id='ch23'").fetchone()
print("frus1920v03/ch23 header:", repr(r[0]) if r else None)
print("check:", check(quotes[26][1],'frus1920v03','ch23'))
# where do the search phrases occur among the 38? just informational
print("\n== search-phrase strings: how many of the 38 cited rows hold each (informational) ==")
c=json.load(open(f"{RUN}/collection.fruscollection"))
pairs=[(e['volumeId'],e['documentId']) for e in c['entries'] if e.get('kind')=='document']
for i in (6,7,8,9):
    q=quotes[i-1][1]; hits=[f"{v}/{d}" for v,d in pairs if check(q,v,d)[0]=='OK']
    print(f"{q!r}: {len(hits)} of 38 cited rows, e.g. {hits[:4]}")
