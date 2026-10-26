# Refuter's segment-strict quotation check (the guide's rule): lower-case both, drop everything but [a-z0-9],
# split the quotation at ellipsis marks, require every segment in order at increasing offsets in
# header || dateline || source_note || body_text of the EXACT (volume_id, document_id).
import json, re, sqlite3, sys
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con=sqlite3.connect(DB, uri=True)
def norm(s): return re.sub(r'[^a-z0-9]', '', s.lower())
def doc_text(v,d):
    r=con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v,d)).fetchone()
    if r is None: return None
    return "".join(x or "" for x in r)
def check(q, v, d):
    t=doc_text(v,d)
    if t is None: return False, "pair not in document_cache"
    nt=norm(t)
    segs=[s for s in re.split(r'\[\.\.\.\]|\.\.\.|…', q) if norm(s)]
    pos=0; offs=[]
    for s in segs:
        i=nt.find(norm(s), pos)
        if i<0: return False, f"segment not found at/after offset {pos}: {s[:60]!r}"
        offs.append(i); pos=i+len(norm(s))
    return True, f"{len(segs)} segment(s) at offsets {offs}"
ov=open('/Users/jbotts/frus-analysis/c3/runs/r2/overview.md',encoding='utf-8').read()
# overview quotations, each attributed to the NEAREST FOLLOWING history.state.gov URL (the citation that closes its sentence)
items=[]
for m in re.finditer(r'"([^"]+)"|“([^”]+)”', ov):
    q=m.group(1) or m.group(2)
    u=re.search(r'https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)', ov[m.end():])
    items.append(("overview", q, u.group(1) if u else None, u.group(2) if u else None, m.start()))
coll=json.load(open('/Users/jbotts/frus-analysis/c3/runs/r2/collection.fruscollection'))
for e in coll['entries']:
    if e['kind']=='excerpt': items.append(("excerpt", e['text'], e['volumeId'], e['documentId'], None))
# memo trace: M-Q anchors -> pairs
memo=open('/Users/jbotts/frus-analysis/c3/runs/r2/memo.md',encoding='utf-8').read()
mq={}
for m in re.finditer(r'\[M-(Q\d+b?)\] Q\d+b? — (frus[^/]+)/(d\d+) \(.*?\): "(.*?)"\n', memo, re.S):
    mq[m.group(1)]=(m.group(2), m.group(3), m.group(4))
ok=0; n=0
print(f"{'kind':8s} {'pair':24s} {'result':6s} note | quotation")
for kind,q,v,d,pos in items:
    if q.strip()=="came to power by force":
        print(f"{kind:8s} {'(question phrase)':24s} SKIP   the question's own words in a Decisions heading, not a document quotation | {q}")
        continue
    n+=1
    if v is None: print(f"{kind:8s} {'NO CITATION':24s} FAIL   no following URL | {q[:70]}"); continue
    good,note=check(q,v,d)
    # which memo quotation holds it (substring of a verified M-Q passage attributed to the same pair)?
    hits=[k for k,(mv,md,mt) in mq.items() if (mv,md)==(v,d) and norm(q) in norm(mt)]
    ok+=good
    print(f"{kind:8s} {v+'/'+d:24s} {'PASS' if good else 'FAIL':6s} {note}; memo={','.join(hits) or 'NONE'} | {q[:70]}")
print(f"\nTOTAL checked {n}, passed {ok}, failed {n-ok}")
print("memo M-Q anchors parsed:", len(mq))
