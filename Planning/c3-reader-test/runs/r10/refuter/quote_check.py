import json, re, sqlite3, sys
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
def norm(s): return re.sub(r'[^a-z0-9]', '', (s or '').lower())
def segs(q):
    parts = re.split(r'\[\.\.\.\]|\.\.\.|…', q)
    return [norm(p) for p in parts if norm(p)]
def doc_text(v, d):
    r = con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if r is None: return None
    return norm((r[0] or '') + (r[1] or '') + (r[2] or '') + (r[3] or ''))
def check(q, v, d):
    t = doc_text(v, d)
    if t is None: return ('NO SUCH ROW', [])
    pos = 0; offs = []
    for s in segs(q):
        i = t.find(s, pos)
        if i < 0: return ('FAIL', offs + [(-1, s[:40])])
        offs.append(i); pos = i + len(s)
    return ('OK', offs)

t = open('/Users/jbotts/frus-analysis/c3/runs/r10/overview.md', encoding='utf-8').read()
results = []
n = 0
for l in t.split('\n'):
    if not l.startswith('>'): continue
    m = re.match(r'>\s*"(.*)"\s*—\s*(.*)$', l)
    q, cit = m.group(1), m.group(2)
    u = re.search(r'historicaldocuments/([A-Za-z0-9\-]+)/([A-Za-z0-9_\-]+)', cit)
    v, d = u.group(1), u.group(2)
    n += 1
    status, offs = check(q, v, d)
    results.append(('overview-block', n, v, d, status, offs, q))
c = json.load(open('/Users/jbotts/frus-analysis/c3/runs/r10/collection.fruscollection'))
n = 0
for e in c['entries']:
    if e.get('kind') != 'excerpt': continue
    n += 1
    status, offs = check(e['text'], e['volumeId'], e['documentId'])
    results.append(('collection-excerpt', n, e['volumeId'], e['documentId'], status, offs, e['text']))
ok = sum(1 for r in results if r[4] == 'OK')
for r in results:
    print(f"{r[0]:18} #{r[1]:02d} {r[2]}/{r[3]:8} {r[4]:6} offsets={r[5]} | {r[6][:70]!r}")
print(f"\n{ok} of {len(results)} pass the segment-strict check")
# excerpt == block quote text?
blocks = [r for r in results if r[0]=='overview-block']
excs = [r for r in results if r[0]=='collection-excerpt']
bset = {(r[2],r[3],r[6]) for r in blocks}; eset = {(r[2],r[3],r[6]) for r in excs}
print('block quotes with an identical excerpt (same pair, same text):', len(bset & eset), 'of', len(bset))
print('block-quote (pair,text) not among excerpts:', bset - eset)
print('excerpt (pair,text) not among block quotes:', eset - bset)
