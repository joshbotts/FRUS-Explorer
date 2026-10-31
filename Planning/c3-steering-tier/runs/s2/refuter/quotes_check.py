# Refuter: segment-strict quotation check over every double-quoted passage in overview.md and every
# excerpt in collection.fruscollection, against header || dateline || source_note || body_text of the
# exact (volume_id, document_id) the memo's trace (excerpts.json = Q1..Q19) gives, and the printed
# citation's URL in the overview resolved independently.
import json, re, sqlite3
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s2"
MAN = "/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
SQL = "SELECT header, COALESCE(dateline,''), COALESCE(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?"
print("SQL:", SQL)

def norm(s): return re.sub(r"[^a-z0-9]", "", s.lower())
def segments(q): return [norm(x) for x in re.split(r"\[\.\.\.\]|\[…\]|…|\.\.\.", q) if norm(x)]

cache = {}
def row(v, d):
    if (v, d) not in cache: cache[(v, d)] = con.execute(SQL, (v, d)).fetchone()
    return cache[(v, d)]

def check(q, v, d):
    r = row(v, d)
    if r is None: return "NO SUCH ROW"
    text = norm("".join(r))
    pos = 0
    for s in segments(q):
        i = text.find(s, pos)
        if i < 0: return "NOT FOUND (segment %r)" % s[:40]
        pos = i + len(s)
    return "FOUND"

# the memo's trace: excerpts.json is Q1..Q19 in M6
trace = [(v, d, t) for v, d, t in json.load(open(RUN + "/excerpts.json"))]
def trace_pair_for(q):
    nq = norm(q)
    hits = [(v, d) for v, d, t in trace if nq and (nq in norm(t) or norm(t) in nq)]
    return hits

manifest = {v["volumeId"]: v["title"] for v in json.load(open(MAN))}
URL = re.compile(r"https://history\.state\.gov/historicaldocuments/(frus[^/\s)]+)/(d\d+)")

text = open(RUN + "/overview.md", encoding="utf-8").read()
lines = text.split("\n")
# every double-quoted passage, straight or curly
QUOTE = re.compile(r'"([^"]+)"|“([^”]+)”')
n = 0; fab = 0; mis = 0; nondoc = 0
print("\n=== OVERVIEW QUOTATIONS ===")
for ln, line in enumerate(lines, 1):
    for m in QUOTE.finditer(line):
        q = m.group(1) or m.group(2)
        n += 1
        # nearest URL after the quote on the same line, else nearest before
        after = [u for u in URL.finditer(line) if u.start() > m.end()]
        before = [u for u in URL.finditer(line) if u.end() < m.start()]
        url_pair = (after[0].group(1), after[0].group(2)) if after else ((before[-1].group(1), before[-1].group(2)) if before else None)
        tp = trace_pair_for(q)
        print(f"\nL{ln} #{n}: \"{q[:90]}{'…' if len(q) > 90 else ''}\"")
        print(f"   trace pair(s) by text: {tp}   printed-citation URL pair: {url_pair}")
        if not tp and url_pair is None:
            nondoc += 1
            print("   -> not a document quotation (term, title or word); no citation applies")
            continue
        pair = tp[0] if tp else url_pair
        res = check(q, *pair)
        print(f"   segment-strict against {pair}: {res}")
        if res != "FOUND":
            fab += 1; print("   ** FABRICATION (not in the traced row)")
        if url_pair is not None and tp and url_pair not in tp:
            mis += 1; print(f"   ** MIS-CITATION: overview credits {url_pair}, trace says {tp}")
        if url_pair is not None and not tp:
            # quote not in excerpts.json: check against URL pair directly (done above as pair)
            print("   (no trace row; checked against the printed citation's pair)")
print(f"\noverview quoted passages: {n}; non-document strings: {nondoc}; fabrications: {fab}; mis-citations: {mis}")

print("\n=== COLLECTION EXCERPTS ===")
col = json.load(open(RUN + "/collection.fruscollection"))
ex = [e for e in col["entries"] if e["kind"] == "excerpt"]
efab = 0
for e in ex:
    res = check(e["text"], e["volumeId"], e["documentId"])
    tp = trace_pair_for(e["text"])
    flag = "" if (e["volumeId"], e["documentId"]) in tp else "  ** pair differs from trace"
    print(f"{e['volumeId']}/{e['documentId']}: {res}{flag}")
    if res != "FOUND": efab += 1
print(f"collection excerpts: {len(ex)}; not found in their row: {efab}")

print("\n=== PRINTED CITATIONS vs manifest (every URL in the overview) ===")
seen = []
for ln, line in enumerate(lines, 1):
    for u in URL.finditer(line):
        v, d = u.group(1), u.group(2)
        pre = line[max(0, u.start() - 200):u.start()]
        mdoc = re.search(r"Document (\d+) \($", pre)
        printed_doc = mdoc.group(1) if mdoc else None
        ok_doc = printed_doc is not None and ("d" + printed_doc) == d
        exists = row(v, d) is not None
        same_vol = "same volume" in pre[-60:]
        seen.append((v, d))
        print(f"L{ln} {v}/{d}: printed 'Document {printed_doc}' matches id={ok_doc}; row exists={exists}; same-volume phrase={same_vol}")
        # printed title vs manifest title
        mt = re.search(r"Foreign Relations of the United States,? ([^()]*?), Document \d+ \($", pre)
        if mt:
            printed = mt.group(1).strip()
            man = manifest.get(v, "?")
            # compare loosely: every word of the printed volume title (minus punctuation) should be in the manifest title
            pw = [w for w in re.findall(r"[A-Za-z0-9–-]+", printed) if w not in ("Diplomatic", "Papers")]
            missing = [w for w in pw if w.lower() not in man.lower().replace("—", "–")]
            print(f"      printed: {printed}")
            print(f"      manifest: {man}")
            print(f"      words of the printed title absent from the manifest title: {missing}")
print("distinct cited pairs:", len(set(seen)), sorted(set(seen)))
