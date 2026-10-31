# Refuter quotation check for cell f9: every straight-double-quoted span in overview.md and every collection excerpt,
# tested by the guide's rule (lower-case, keep [a-z0-9], split at ellipses, segments in order) against
# header||dateline||source_note||body_text of the cited pair.
import sqlite3, re, json
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f9/"
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
c = sqlite3.connect(DB, uri=True)
man = json.load(open(RES + "manifest.json"))
rec0 = man[0] if isinstance(man, list) else man
print("manifest type", type(man).__name__, "first record keys:", list(rec0.keys())[:20] if isinstance(rec0, dict) else rec0)

def norm(s):
    return re.sub(r'[^a-z0-9]', '', s.lower())

texts = {}
def doc_text(v, d):
    if (v, d) not in texts:
        r = c.execute("SELECT coalesce(header,''), coalesce(dateline,''), coalesce(source_note,''), coalesce(body_text,'') FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
        texts[(v, d)] = norm(''.join(r)) if r else None
    return texts[(v, d)]

def check(q, v, d):
    t = doc_text(v, d)
    if t is None: return False, "pair not in index"
    segs = [norm(s) for s in re.split(r'…|\.\.\.|\[\.\.\.\]', q) if norm(s)]
    pos = 0
    for s in segs:
        i = t.find(s, pos)
        if i < 0: return False, f"segment not found: {s[:60]}"
        pos = i + len(s)
    return True, f"{len(segs)} segment(s) found in order"

# --- manifest title -> volume id
titles = {}
for rec in (man if isinstance(man, list) else man.get('volumes', [])):
    titles[rec.get('title', '')] = rec.get('volumeId')

def resolve_printed(cit):
    # cit like "Foreign Relations of the United States, 1952–1954, Indochina, Volume XIII, Part 1, Document 116"
    m = re.match(r'Foreign Relations of the United States, (.*), Document (\d+)$', cit.strip())
    if not m: return None, None, "unparsed"
    title_part, docno = m.group(1), m.group(2)
    # try to find a manifest title containing the year span and volume
    cands = []
    for t, vid in titles.items():
        tn = re.sub(r'\s+', ' ', t)
        if title_part.replace('–', '-') in tn.replace('–', '-') or tn.replace('–', '-').endswith(title_part.replace('–', '-')):
            cands.append((t, vid))
    if len(cands) == 1: return cands[0][1], f"d{docno}", f"manifest title match: {cands[0][0]}"
    # looser: match on volume words
    key = re.sub(r'Foreign Relations of the United States, ', '', title_part)
    cands = [(t, vid) for t, vid in titles.items() if all(w in t for w in re.split(r', |; ', key))]
    if len(cands) == 1: return cands[0][1], f"d{docno}", f"manifest title match (loose): {cands[0][0]}"
    return None, None, f"ambiguous/none: {cands[:3]}"

ov = open(RUN + "overview.md").read()
# straight double-quoted spans
spans = [(m.start(), m.end(), m.group(1)) for m in re.finditer(r'"([^"]+)"', ov)]
print("straight-double-quoted spans in overview:", len(spans))

url_re = re.compile(r'historicaldocuments/([^/\s)]+)/(d\d+)')
same_re = re.compile(r'Document (\d+) of the same volume')
printed_re = re.compile(r'\((Foreign Relations of the United States, [^()]*?Document \d+)\)')

# all citations with positions, in order
cits = []
for m in url_re.finditer(ov): cits.append((m.start(), 'url', (m.group(1), m.group(2))))
for m in same_re.finditer(ov): cits.append((m.start(), 'same', m.group(1)))
for m in printed_re.finditer(ov):
    if 'history.state.gov' not in m.group(0):
        cits.append((m.start(), 'printed', m.group(1)))
cits.sort()

def citation_after(pos):
    """nearest citation after pos; resolve 'same volume' using the nearest earlier url citation."""
    for p, kind, val in cits:
        if p >= pos:
            if kind == 'url': return val, f"url at +{p-pos}"
            if kind == 'printed':
                v, d, how = resolve_printed(val); return (v, d), f"printed citation at +{p-pos}; {how}"
            if kind == 'same':
                prev = [x for x in cits if x[0] < p and x[1] == 'url']
                pv = prev[-1][2][0] if prev else None
                return (pv, f"d{val}"), f"'same volume' at +{p-pos}; volume from preceding url {pv}"
    return (None, None), "no citation after"

NONDOC = {"soft power", "Soft power", "soft", "Department of State", "Asian", "Oriental", "USI", "South and Southeast Asia",
          "cultural relations program", "American soft power in East Asia and the Pacific — run f9"}
# memo's trace: quotes.tsv
Q = {}
for line in open(RUN + "quotes.tsv"):
    q, v, d, t = line.rstrip('\n').split('\t'); Q[t] = (q, v, d)

results = []
for s, e, q in spans:
    if q in NONDOC:
        results.append((q, None, 'non-document span', None, None)); continue
    (v, d), how = citation_after(e)
    ok, why = check(q, v, d)
    # memo's trace pair for this text (the Q whose text contains it)
    memo = [(qq, vv, dd) for t, (qq, vv, dd) in Q.items() if norm(q) in norm(t)]
    results.append((q, (v, d), how, (ok, why), memo))

print("\n=== OVERVIEW SPANS ===")
nd = 0; ok_n = 0; fab = []; mis = []
for q, pair, how, res, memo in results:
    if pair is None:
        nd += 1; print(f"NONDOC  | {q}"); continue
    ok, why = res
    memo_pairs = sorted(set((vv, dd) for qq, vv, dd in memo))
    flag = ""
    if not ok:
        # is it in the memo's pair instead? -> mis-citation; else fabrication
        alt = [mp for mp in memo_pairs if check(q, *mp)[0]]
        if alt: flag = f"MIS-CITATION (found in memo pair {alt})"; mis.append((q, pair, alt))
        else: flag = "FABRICATION (not found in cited pair; memo pair also fails or none)"; fab.append((q, pair))
    else:
        ok_n += 1
        if memo_pairs and pair not in memo_pairs: flag = f"NOTE memo trace pair differs {memo_pairs}"
    print(f"{'OK ' if ok else 'BAD'} | {pair[0]}/{pair[1]} | {how} | {why} | memo:{[m[0] for m in memo]} {flag}\n      \"{q[:110]}\"")
print(f"\noverview: document spans {len(results)-nd}, verified {ok_n}, fabrications {len(fab)}, mis-citations {len(mis)}, non-document spans {nd}")

print("\n=== COLLECTION EXCERPTS ===")
col = json.load(open(RUN + "collection.fruscollection"))
ex_ok = 0; ex_bad = []
exs = [e for e in col['entries'] if e['kind'] == 'excerpt']
for e in exs:
    ok, why = check(e['text'], e['volumeId'], e['documentId'])
    # memo trace pair
    memo = Q.get(e['text'])
    mflag = "" if (memo and (memo[1], memo[2]) == (e['volumeId'], e['documentId'])) else f" memo-trace:{memo}"
    if ok: ex_ok += 1
    else: ex_bad.append(e)
    print(f"{'OK ' if ok else 'BAD'} | {e['volumeId']}/{e['documentId']} | {why}{mflag} | \"{e['text'][:90]}\"")
print(f"\nexcerpts {len(exs)}, verified {ex_ok}, failed {len(ex_bad)}")

# excerpt uniqueness: does each excerpt occur once in its doc's body (memo says each occurs once)?
print("\n=== occurrence counts of excerpts in body_text (raw) ===")
for e in exs:
    b = c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?", (e['volumeId'], e['documentId'])).fetchone()[0]
    n = b.count(e['text'])
    if n != 1: print("  count", n, e['volumeId'], e['documentId'], e['text'][:60])
print("done")
