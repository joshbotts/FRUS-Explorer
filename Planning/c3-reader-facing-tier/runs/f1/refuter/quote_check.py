#!/usr/bin/env python3
"""Refuter quotation check for cell f1: every double-quoted span in overview.md and every collection excerpt,
checked segment-strict against header||dateline||source_note||body_text of the exact cited pair."""
import sqlite3, re, json
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f1"
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c = sqlite3.connect(DB, uri=True)
man = json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
title_of = {m['filename'][:-4]: re.sub(r'\s+', ' ', m.get('title', '')) for m in man}

def norm(s):
    return re.sub(r'[^a-z0-9]', '', s.lower())

def surface(v, d):
    r = c.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if r is None:
        return None
    return norm(''.join(x or '' for x in r))

def check(quote, v, d):
    """The guide's rule: split at ellipses, each segment in order at increasing offsets."""
    surf = surface(v, d)
    if surf is None:
        return False, "pair not in document_cache"
    segs = [s for s in re.split(r'…|\.\.\.|\[\.\.\.\]', quote) if norm(s)]
    pos = 0; found = []
    for s in segs:
        k = surf.find(norm(s), pos)
        if k < 0:
            return False, f"segment not found at/after offset {pos}: {s[:50]!r}"
        found.append(k); pos = k + len(norm(s))
    return True, f"offsets {found}"

text = open(RUN + "/overview.md").read()
# resolve the short edition citations through manifest.json
def resolve_short(cit):
    m = re.match(r'(\d{4}(?:–\d{4})?), Volume ([IVXL]+)(?:, Part (\d))?, Document (\d+)', cit)
    if not m:
        return None
    years, vol, part, doc = m.groups()
    cands = []
    for fid, t in title_of.items():
        if years in t and re.search(r'Volume ' + vol + r'\b', t) and ((part and f'Part {part}' in t) or (not part and 'Part' not in t)):
            cands.append(fid)
    return cands, f"d{doc}"

# citation markers in order
markers = []
for m in re.finditer(r'https://history\.state\.gov/historicaldocuments/(frus[^/\s)]+)/(d\d+)', text):
    markers.append((m.start(), ('url', m.group(1), m.group(2))))
for m in re.finditer(r'\(same volume, Document (\d+)', text):
    markers.append((m.start(), ('same', None, 'd' + m.group(1))))
for m in re.finditer(r'\((\d{4}(?:–\d{4})?, Volume [IVXL]+(?:, Part \d)?, Document \d+)\)', text):
    markers.append((m.start(), ('short', m.group(1), None)))
markers.sort()

def cite_after(pos):
    """First citation marker after pos; 'same volume' resolves to the previous URL marker's volume."""
    for i, (p, mk) in enumerate(markers):
        if p > pos:
            kind, a, b = mk
            if kind == 'url':
                return (a, b), 'url'
            if kind == 'same':
                for pp, mk2 in reversed(markers[:i]):
                    if mk2[0] == 'url':
                        return (mk2[1], b), 'same volume → ' + mk2[1]
                return None, 'same volume unresolved'
            if kind == 'short':
                cands, d = resolve_short(a)
                if cands and len(cands) == 1:
                    return (cands[0], d), f'short citation resolved via manifest.json: {a!r} → {cands[0]}'
                return None, f'short citation ambiguous/unresolved via manifest: {a!r} → {cands}'
    return None, 'no citation after'

quotes = [(m.start(), m.end(), m.group(1)) for m in re.finditer(r'"([^"\n]+)"', text)]
print(f"double-quoted spans in overview.md: {len(quotes)}")
# memo's Q table, for the trace
memo = open(RUN + "/memo.md").read()
qtab = {}
for m in re.finditer(r'^\| (Q\d+) \| ([^|]+?) \| [^|]* \| (.+?) \|$', memo, re.M):
    qtab[m.group(1)] = (m.group(2).strip(), m.group(3).strip())
print("memo Q rows:", len(qtab))

NONDOC = {'information program', 'psychological strategy', 'image', 'credibility', 'soft power', 'messaging', 'Messaging',
          'Department of State', 'USI', 'message', 'East Asia and Pacific', 'Far East', 'Soft power', 'Messaging".* The literal word occurs in three documents in the whole series. The search engine treats ',
          'International Informational and Educational Relations', 'What counts as ', 'American soft power in East Asia and the Pacific: how policymakers assessed it'}
results = []
n_doc = 0; n_ok = 0; fab = []; mis = []
for s, e, qtext in quotes:
    line = text.count('\n', 0, s) + 1
    if qtext in NONDOC or len(qtext) < 20 and not re.search(r'[a-z]{4,} [a-z]{4,} [a-z]{3,}', qtext):
        results.append((line, qtext, 'NOT A DOCUMENT QUOTATION', None, None))
        continue
    pair, how = cite_after(e)
    # memo trace: which Q holds this text?
    trace = [k for k, (p, passage) in qtab.items() if norm(qtext.rstrip('…')) and norm(qtext.rstrip('…')) in norm(passage)]
    n_doc += 1
    if pair is None:
        results.append((line, qtext, 'UNRESOLVED CITATION: ' + how, None, trace)); mis.append((line, qtext[:60], how)); continue
    ok, why = check(qtext, *pair)
    # does the memo's trace pair agree with the overview's citation?
    memo_pairs = {qtab[k][0] for k in trace}
    agree = (f"{pair[0]}/{pair[1]}" in memo_pairs) if trace else None
    verdict = 'OK' if ok else 'FAIL'
    if ok: n_ok += 1
    else:
        # is it in the memo's pair instead (mis-citation) or nowhere (fabrication)?
        alt = None
        for mp in memo_pairs:
            mv, md = mp.split('/')
            if check(qtext, mv, md)[0]: alt = mp
        if alt: mis.append((line, qtext[:60], f"cited {pair}, found in {alt}"))
        else: fab.append((line, qtext[:60], f"cited {pair}: {why}"))
    results.append((line, qtext, verdict, f"{pair[0]}/{pair[1]} [{how}] {why}; memo trace {trace} agree={agree}", trace))

for r in results:
    print(f"L{r[0]:3d} {r[2]:28s} {r[1][:70]!r} :: {r[3] or ''}")
print(f"\nDOCUMENT QUOTATIONS in overview: {n_doc}; verified {n_ok}; fabrications {len(fab)}; mis-citations {len(mis)}")
for f in fab: print("  FAB", f)
for m in mis: print("  MIS", m)

print("\n=== collection excerpts ===")
coll = json.load(open(RUN + "/collection.fruscollection"))
ex_ok = 0; ex_n = 0; ex_bad = []
for e in coll['entries']:
    if e.get('kind') != 'excerpt': continue
    ex_n += 1
    ok, why = check(e['text'], e['volumeId'], e['documentId'])
    if ok: ex_ok += 1
    else: ex_bad.append((e['volumeId'], e['documentId'], e['text'][:60], why))
    print(f"  {'OK ' if ok else 'BAD'} {e['volumeId']}/{e['documentId']} {e['text'][:60]!r} {why}")
print(f"excerpts: {ex_n}, verified {ex_ok}, bad {ex_bad}")
# memo's Q table pairs vs quotes.json vs collection excerpts
qj = json.load(open(RUN + "/quotes.json"))
print("quotes.json n:", len(qj), "; equals collection excerpts (pair,text):",
      sorted((v, d, t) for v, d, t in qj) == sorted((e['volumeId'], e['documentId'], e['text']) for e in coll['entries'] if e['kind'] == 'excerpt'))
print("collection name:", coll['name'])
print("overview names the collection as:", re.search(r'\*\*"([^"]+)"\*\*', text).group(1))

print("\n=== class gloss against decimal-class-labels.json ===")
dcl = json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/decimal-class-labels.json"))
s = json.dumps(dcl)
print("'International Informational and Educational Relations' in decimal-class-labels.json:", 'International Informational and Educational Relations' in s)
for hit in set(re.findall(r'"([^"]*International Informational and Educational Relations[^"]*)"', s)): print("  label:", hit)
