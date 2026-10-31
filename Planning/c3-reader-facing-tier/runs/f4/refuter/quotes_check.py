#!/usr/bin/env python3
"""Refuter quotation check for cell f4: the guide's rule, applied to every quoted string in overview.md
and every excerpt in collection.fruscollection, against the exact (volume_id, document_id) the memo's trace gives."""
import json, re, sqlite3
RUN = '/Users/jbotts/frus-analysis/c3f/runs/f4/'
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c = sqlite3.connect(DB, uri=True)
man = json.load(open('/Applications/FRUS Explorer.app/Contents/Resources/manifest.json'))
title_of = {v['volumeId']: re.sub(r'\s+', ' ', v['title']) for v in man}

def squash(s):
    return re.sub(r'[^a-z0-9]', '', s.lower())

def doc_text(v, d):
    r = c.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if r is None:
        return None
    return squash((r[0] or '') + (r[1] or '') + (r[2] or '') + (r[3] or ''))

cache = {}
def check(quote, v, d):
    """The guide's rule: split at ellipses, each segment in order at increasing offsets."""
    key = (v, d)
    if key not in cache:
        cache[key] = doc_text(v, d)
    t = cache[key]
    if t is None:
        return False, 'pair not in document_cache'
    segs = [squash(s) for s in re.split(r'…|\.\.\.|\[\.\.\.\]', quote)]
    segs = [s for s in segs if s]
    pos = 0
    for s in segs:
        i = t.find(s, pos)
        if i < 0:
            return False, f'segment not found: {s[:60]}'
        pos = i + len(s)
    return True, 'ok'

# ---- Overview: every double-quoted string, and the citation that follows each ----
s = open(RUN + 'overview.md').read()
main, _, cited_list = s.partition('## Documents cited')
full = re.findall(r'^\d+\. (Foreign Relations of the United States, [^\n]*?), Document (\d+)\. (https://\S+)', cited_list, re.M)
def key_of(t, n):
    y = re.match(r'Foreign Relations of the United States, (\d{4}(?:–\d{4})?)', t).group(1)
    vol = re.search(r'(Volume [IVXL]+(?:, Part \d)?)', t).group(1)
    return f"{y}, {vol}, Document {n}"
list_map = {}
for t, n, u in full:
    v, d = re.search(r'historicaldocuments/([^/]+)/(d\d+)', u).groups()
    list_map[key_of(t, n)] = (v, d, t)
print('Documents cited list entries:', len(full))

# verify each list entry resolves: document_number in document_cache == printed Document n, and manifest title agrees
print('\n== Documents cited list: resolution through manifest.json and document_cache ==')
for t, n, u in full:
    v, d = re.search(r'historicaldocuments/([^/]+)/(d\d+)', u).groups()
    r = c.execute("SELECT document_number, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    mt = title_of.get(v, 'NOT IN MANIFEST')
    vol = re.search(r'(Volume [IVXL]+(?:, Part \d)?)', t).group(1)
    yrs = re.match(r'Foreign Relations of the United States, (\d{4}(?:–\d{4})?)', t).group(1)
    ok_num = (r is not None and str(r[0]).strip() == n)
    ok_title = (vol.split(',')[0] in mt) and (yrs in mt)
    print(f"  {v}/{d}: printed Document {n}; document_cache number={r[0] if r else None} apparatus={(r[1], r[2]) if r else None}; number-match={ok_num}; manifest title='{mt[:90]}' title-match={ok_title}")

quotes = [(m.start(), m.group(1)) for m in re.finditer(r'"([^"]+)"', main)]
cite_re = re.compile(r'\((\d{4}(?:–\d{4})?, Volume [IVXL]+(?:, Part \d)?, Document \d+)\)')
# memo's Q table: quotation text -> pair (for the mapping the memo gives)
memo = open(RUN + 'memo.md').read()
qrows = re.findall(r'^\| (Q\d\d) \| ([^/|]+)/(d\d+) \| (\*?) *\| (.+?) \|$', memo, re.M)
memo_pairs = [(qid, v, d, txt.strip()) for qid, v, d, star, txt in qrows]
print('memo Q rows:', len(memo_pairs))

print('\n== Overview quoted strings ==')
fab = 0; mis = 0; docq = 0; ok = 0
for pos, qt in quotes:
    qn = qt.strip().rstrip(',.')
    # the memo's pair: the Q row whose squashed text contains this quotation
    memo_hits = [(qid, v, d) for qid, v, d, txt in memo_pairs if squash(qn) and squash(qn) in squash(txt)]
    # the overview's own citation: the next (year, Volume, Document) after the quote
    m = cite_re.search(main, pos)
    cit = m.group(1) if m else None
    cit_pair = list_map.get(cit, (None, None, None))[:2] if cit else (None, None)
    if not memo_hits:
        print(f"  NOT-A-DOCUMENT-QUOTATION (no memo Q row): \"{qt[:70]}\"  next citation: {cit}")
        continue
    docq += 1
    qid, mv, md = memo_hits[0]
    res, why = check(qn, mv, md)
    # mis-citation: the overview's citation resolves to a different pair than the memo's
    same = (cit_pair == (mv, md))
    verdict = 'OK' if (res and same) else ('FABRICATION' if not res else 'MIS-CITATION')
    if verdict == 'OK': ok += 1
    elif verdict == 'FABRICATION': fab += 1
    else: mis += 1
    # also test the quote against the overview's own cited pair
    res2, why2 = check(qn, *cit_pair) if cit_pair[0] else (None, 'no citation')
    print(f"  {verdict}: {qid} memo-pair {mv}/{md} found={res} ({why}); overview cites {cit} -> {cit_pair} found-there={res2}; \"{qt[:70]}\"")
print(f"overview: document quotations {docq}, ok {ok}, fabrications {fab}, mis-citations {mis}")

# ---- Collection excerpts ----
print('\n== Collection excerpts ==')
coll = json.load(open(RUN + 'collection.fruscollection'))
ex = [e for e in coll['entries'] if e.get('kind') == 'excerpt']
efab = 0; eok = 0
for e in ex:
    res, why = check(e['text'], e['volumeId'], e['documentId'])
    if res: eok += 1
    else: efab += 1
    print(f"  {'OK' if res else 'FABRICATION'}: {e['volumeId']}/{e['documentId']} ({why}) \"{e['text'][:70]}\"")
print(f"excerpts {len(ex)}, ok {eok}, fabrications {efab}")

# ---- Memo's 39 Q rows, re-checked by the guide's rule (not the memo's whitespace rule) ----
print('\n== Memo Q table, all rows ==')
bad = 0
for qid, v, d, txt in memo_pairs:
    res, why = check(txt, v, d)
    if not res:
        bad += 1
        print(f"  FAIL {qid} {v}/{d}: {why}")
print(f"memo Q rows checked {len(memo_pairs)}, failing {bad}")
