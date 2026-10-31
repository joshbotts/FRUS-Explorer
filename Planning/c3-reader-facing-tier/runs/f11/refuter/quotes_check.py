import re, json, sqlite3, sys
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f11/"
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)

def norm(s):
    return re.sub(r"[^a-z0-9]", "", (s or "").lower())

def doc_text(v, d):
    r = db.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if r is None:
        return None
    return norm((r[0] or "") + (r[1] or "") + (r[2] or "") + (r[3] or ""))

def segments(q):
    parts = re.split(r"\[\.\.\.\]|\.\.\.|…", q)
    return [norm(p) for p in parts if norm(p)]

def check(q, v, d):
    t = doc_text(v, d)
    if t is None:
        return False, "pair not in index"
    pos = 0
    for s in segments(q):
        i = t.find(s, pos)
        if i < 0:
            return False, "segment missing: %r" % s[:60]
        pos = i + len(s)
    return True, "ok"

ov = open(RUN + "overview.md").read()
# overview quotes with the nearest following URL
url_re = re.compile(r"https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+[a-z]?)")
quotes = [(m.start(), m.end(), m.group(1)) for m in re.finditer(r"“([^”]+)”", ov)]
urls = [(m.start(), m.group(1), m.group(2)) for m in url_re.finditer(ov)]
# memo trace pairs
memo = open(RUN + "memo.md").read()
trace = {}
for m in re.finditer(r"^\| (Q\d+) \| ([^/|]+)/(d\d+) \|", memo, flags=re.M):
    trace[m.group(1)] = (m.group(2).strip(), m.group(3))

# all collection docs, to test "found elsewhere"
c = json.load(open(RUN + "collection.fruscollection"))
coll_pairs = [(e["volumeId"], e["documentId"]) for e in c["entries"] if e["kind"] == "document"]
coll_text = {k: doc_text(*k) for k in coll_pairs}

print("== OVERVIEW QUOTATIONS (nearest following URL = cited pair) ==")
fab = 0; mis = 0; okn = 0
for n, (s, e, q) in enumerate(quotes, 1):
    nxt = [u for u in urls if u[0] >= e]
    cited = (nxt[0][1], nxt[0][2]) if nxt else None
    ok, why = check(q, *cited) if cited else (False, "no url")
    tp = trace.get("Q%d" % n)
    tok = check(q, *tp)[0] if tp else None
    elsewhere = [k for k, t in coll_text.items() if t and all(seg in t for seg in segments(q))]
    verdict = "OK" if ok else ("MIS-CITATION (found in %s)" % elsewhere if elsewhere else "FABRICATION")
    if ok: okn += 1
    elif elsewhere: mis += 1
    else: fab += 1
    flag = "" if tp == cited else "  <-- memo trace pair %s differs from cited %s" % (tp, cited)
    print("Q%-2d cited=%s/%s %-5s | memo=%s/%s in-memo-pair=%s%s\n     %s" % (n, cited[0], cited[1], verdict if ok else "", tp[0] if tp else None, tp[1] if tp else None, tok, flag, q[:120]))
    if not ok: print("     ** %s -> %s" % (why, verdict))
print("overview quotations:", len(quotes), "ok:", okn, "fabrications:", fab, "mis-citations:", mis)

print("\n== COLLECTION EXCERPTS ==")
nex = 0; exok = 0
for e in c["entries"]:
    if e["kind"] != "excerpt":
        continue
    nex += 1
    ok, why = check(e["text"], e["volumeId"], e["documentId"])
    if ok: exok += 1
    else:
        print("EXCERPT FAIL %s/%s: %s | %s" % (e["volumeId"], e["documentId"], why, e["text"][:100]))
print("excerpts:", nex, "ok:", exok)

# single-quoted terms in the overview, for the record
terms = re.findall(r"‘([^’]+)’", ov)
print("\nsingle-quoted terms in the overview (vocabulary, not quotations):", len(terms), sorted(set(terms)))
