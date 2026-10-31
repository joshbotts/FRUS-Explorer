import json, re, sqlite3, sys
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f8/"
c = sqlite3.connect(DB, uri=True)

def norm(s):
    return re.sub(r'[^a-z0-9]', '', s.lower())

def doc_text(v, d):
    r = c.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if not r:
        return None
    return "".join(x or "" for x in r)

def check(q, v, d):
    """Guide's rule: split at ellipsis marks, every segment in order at increasing offsets."""
    t = doc_text(v, d)
    if t is None:
        return False, "PAIR ABSENT"
    nt = norm(t)
    segs = [s for s in re.split(r'…|\.\.\.|\[\.\.\.\]', q) if norm(s)]
    pos = 0
    for s in segs:
        ns = norm(s)
        i = nt.find(ns, pos)
        if i < 0:
            return False, f"segment not found: {s[:60]!r}"
        pos = i + len(ns)
    return True, f"ok ({len(segs)} seg)"

# --- overview: resolve short citations through the Documents cited list ---
ov = open(RUN + "overview.md", encoding="utf-8").read()
cited = {}
for m in re.finditer(r'^\d+\. Foreign Relations of the United States, (.+?) — https://history\.state\.gov/historicaldocuments/([^/]+)/(d\d+)\s*$', ov, re.M):
    cited[m.group(1)] = (m.group(2), m.group(3))

def resolve_short(cit):
    """'1952–1954, Volume XII, Part 2, Document 403' -> pair via the list (years, Volume, Part, Document)."""
    m = re.match(r'(\d{4}(?:–\d{4})?), Volume ([IVXL]+)(?:, Part (\d))?, Document (\d+)', cit)
    if not m:
        return None
    yrs, vol, part, doc = m.groups()
    hits = []
    for title, pair in cited.items():
        if title.startswith(yrs) and re.search(r'Volume %s\b' % vol, title) and ((part is None and 'Part' not in title) or (part and f'Part {part}' in title)) and title.endswith(f'Document {doc}'):
            hits.append(pair)
    return hits[0] if len(hits) == 1 else (hits or None)

print("Documents cited list:", len(cited))
# every in-text short citation resolves?
short = re.findall(r'\((\d{4}(?:–\d{4})?, Volume [IVXL]+(?:, Part \d)?, Document \d+)(?:; (\d{4}(?:–\d{4})?, Volume [IVXL]+(?:, Part \d)?, Document \d+))*\)', ov)
allshort = set()
for m in re.finditer(r'\d{4}(?:–\d{4})?, Volume [IVXL]+(?:, Part \d)?, Document \d+', ov):
    allshort.add(m.group(0))
unres = [s for s in sorted(allshort) if not resolve_short(s)]
print("short citations:", len(allshort), "unresolved:", unres)

# --- extract the overview's quotations with the pair the surrounding text assigns ---
# Approach: walk the Findings/bottom-line text; for each quoted passage, take the nearest
# following citation in the same paragraph, or '(Document N above)' / '(Document N)' back-reference.
body = ov
paras = body.split("\n")
results = []
last_pair = None
docno_to_pair = {}
for title, pair in cited.items():
    docno_to_pair.setdefault(pair[1], set()).add(pair)

for para in paras:
    # block quote
    is_block = para.startswith(">")
    text = para.lstrip("> ").strip()
    # find quotes "..." (straight) in the paragraph
    quotes = []
    if is_block:
        # block quote: text up to the citation in parentheses at end
        m = re.match(r'(.*?)\s*\(([^()]*)\)\s*$', text)
        if m:
            quotes.append((m.group(1).strip(), m.group(2)))
        else:
            quotes.append((text, None))
    else:
        for m in re.finditer(r'"([^"]+)"', text):
            q = m.group(1)
            # citation: nearest '(' ... ')' after the quote in this paragraph that holds Document
            after = text[m.end():]
            cm = re.search(r'\(((?:[^()]*Document \d+[^()]*))\)', after)
            quotes.append((q, cm.group(1) if cm else None))
    for q, cit in quotes:
        results.append((q, cit, is_block))

def cit_to_pair(cit, q):
    if cit is None:
        return None
    # may hold several citations separated by ';' -> take the first that holds the quote
    cands = []
    for part in cit.split(";"):
        part = part.strip()
        mm = re.search(r'(\d{4}(?:–\d{4})?, Volume [IVXL]+(?:, Part \d)?, Document \d+)', part)
        if mm:
            p = resolve_short(mm.group(1))
            if p: cands.append(p if isinstance(p, tuple) else p[0])
            continue
        mm = re.match(r'Document (\d+)(?: above)?$', part)
        if mm:
            ps = docno_to_pair.get("d" + mm.group(1), set())
            cands.extend(sorted(ps))
    return cands

print()
print("=== OVERVIEW QUOTATIONS ===")
n_doc = 0; n_ok = 0; fabs = []; miscite = []
for q, cit, blk in results:
    cands = cit_to_pair(cit, q)
    tag = "BLOCK" if blk else "INLINE"
    if not cands:
        print(f"[{tag}] NO-DOC-CITATION {q[:90]!r}  cit={cit!r}")
        continue
    n_doc += 1
    verdicts = [(p, check(q, *p)) for p in cands]
    good = [p for p, (ok, _) in verdicts if ok]
    if good:
        n_ok += 1
        print(f"[{tag}] OK   {good[0][0]}/{good[0][1]}  {q[:80]!r}" + ("" if len(cands)==1 else f"  (ambiguous Document N: {cands}, found in {good})"))
    else:
        # found anywhere else in corpus?
        print(f"[{tag}] FAIL {cands}  {q[:80]!r}  -> {verdicts}")
        fabs.append((q, cands))
print(f"overview document-quotations: {n_doc}, verified: {n_ok}, failed: {len(fabs)}")

print()
print("=== COLLECTION EXCERPTS ===")
col = json.load(open(RUN + "collection.fruscollection", encoding="utf-8"))
ne = 0; neok = 0
for e in col["entries"]:
    if e["kind"] != "excerpt":
        continue
    ne += 1
    ok, why = check(e["text"], e["volumeId"], e["documentId"])
    neok += ok
    print(("OK  " if ok else "FAIL"), e["volumeId"] + "/" + e["documentId"], e["text"][:80], "" if ok else why)
print(f"collection excerpts: {ne}, verified: {neok}")

print()
print("=== NON-DOCUMENT QUOTED STRINGS in overview (listed, not counted) ===")
for q, cit, blk in results:
    if not cit_to_pair(cit, q):
        print(repr(q), "cit=", cit)
# 'RG 305' against d105's source note
t = doc_text("frus1969-76v38p2", "d105")
print("RG 305 in d105 text:", "rg305" in norm(t))
sn = c.execute("SELECT source_note FROM document_cache WHERE volume_id='frus1969-76v38p2' AND document_id='d105'").fetchone()[0]
print("d105 source_note:", sn[:200])
