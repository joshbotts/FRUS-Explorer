# Refuter's quotation check for run f12 (the guide's rule): lower-case, strip to [a-z0-9], split at ellipses,
# every segment in order at increasing offsets in header||dateline||source_note||body_text of the EXACT pair cited.
import re, json, sqlite3, sys
R = "/Users/jbotts/frus-analysis/c3f/runs/f12"
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)

def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())

def surface(v, d):
    r = con.execute("SELECT header, dateline, source_note, body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if not r:
        return None, None
    return norm((r[0] or "") + (r[1] or "") + (r[2] or "") + (r[3] or "")), (r[4], r[5])

def check(quote, v, d):
    surf, flags = surface(v, d)
    if surf is None:
        return False, "NO SUCH ROW", []
    segs = [norm(s) for s in re.split(r"…|\.\.\.|\[\.\.\.\]", quote)]
    segs = [s for s in segs if s]
    pos = 0; found = []
    for s in segs:
        i = surf.find(s, pos)
        if i < 0:
            return False, f"segment not found at/after offset {pos}: {s[:60]}", found
        found.append(i); pos = i + len(s)
    return True, "ok", found

ov = open(R + "/overview.md").read()
paras = ov.split("\n")

# --- citations: URL pairs, and the three 'above' forms ---
VOLNAME = {"Public Diplomacy, 1961–1963": "frus1917-72PubDipv06", "Public Diplomacy, 1964–1968": "frus1917-72PubDipv07",
           "Public Diplomacy, 1969–1972": "frus1917-72PubDipv08", "Public Diplomacy, 1973–1976": "frus1969-76v38p2"}
cite_re = re.compile(r"\(([^()]*?(?:\([^()]*\)[^()]*?)*?)\)")  # parenthesised citation, allowing one nested level

def resolve_citation(text, last_vol):
    m = re.search(r"historicaldocuments/([^/\s)]+)/(d\d+\w*)", text)
    if m:
        return (m.group(1), m.group(2)), "url"
    m = re.search(r"Document (\d+)", text)
    if not m:
        return None, None
    doc = "d" + m.group(1)
    for k, v in VOLNAME.items():
        if k in text:
            return (v, doc), "above/" + k
    if "same volume" in text and last_vol:
        return (last_vol, doc), "same volume"
    return None, "unresolved: " + text[:80]

NONQUOTE_TERMS = {"soft power", "RG 305", "Restricted - Possibly", "Department of State", "image of the United States", "psychological",
                  "public diplomacy", "Public Opinion Research", "the region"}

rows = []
qn = 0
for pi, p in enumerate(paras):
    if '"' not in p:
        continue
    qpos = [i for i, ch in enumerate(p) if ch == '"']
    if len(qpos) % 2:
        print("ODD QUOTE COUNT in paragraph", pi); continue
    spans = [(qpos[i] + 1, qpos[i + 1]) for i in range(0, len(qpos), 2)]
    # citations in this paragraph
    cites = []
    last_vol = None
    for m in cite_re.finditer(p):
        pair, how = resolve_citation(m.group(1), last_vol)
        if pair:
            cites.append((m.start(), m.end(), pair, how)); last_vol = pair[0]
    for (a, b) in spans:
        q = p[a:b]
        qn += 1
        if q in NONQUOTE_TERMS or q.startswith("American soft power in East Asia"):
            rows.append({"n": qn, "para": pi + 1, "quote": q, "kind": "term/name", "pair": None}); continue
        # the citation that governs this quote: the first citation starting after the quote ends (same paragraph)
        gov = next(((s, e, pr, how) for (s, e, pr, how) in cites if s >= b), None)
        if gov is None:
            rows.append({"n": qn, "para": pi + 1, "quote": q, "kind": "quotation", "pair": None, "how": "NO CITATION FOLLOWS IN PARAGRAPH"}); continue
        ok, why, offs = check(q, *gov[2])
        rows.append({"n": qn, "para": pi + 1, "quote": q, "kind": "quotation", "pair": gov[2], "how": gov[3], "ok": ok, "why": why, "offsets": offs})

print("=== OVERVIEW QUOTED SPANS ===")
nq = nterm = nok = nbad = 0
for r in rows:
    if r["kind"] == "term/name":
        nterm += 1; print(f"[{r['n']:02d}] TERM/NAME  para {r['para']}: \"{r['quote']}\""); continue
    nq += 1
    if r.get("ok"):
        nok += 1; print(f"[{r['n']:02d}] OK   {r['pair'][0]}/{r['pair'][1]} ({r['how']}) offsets {r['offsets']}: \"{r['quote'][:100]}\"")
    else:
        nbad += 1; print(f"[{r['n']:02d}] FAIL {r.get('pair')} ({r.get('how')}) {r.get('why')}: \"{r['quote'][:100]}\"")
print(f"quoted spans total {qn}: document quotations {nq} (ok {nok}, fail {nbad}); terms/names {nterm}")

# --- cross-check against the memo's trace: each verified quote must also be a (sub)string of a memo Q whose pair matches the cited pair ---
quotes = json.load(open(R + "/quotes.json"))
print("\n=== TRACE CROSS-CHECK (overview citation pair vs memo Q pair) ===")
for r in rows:
    if r["kind"] != "quotation" or not r.get("pair"):
        continue
    segs = [norm(s) for s in re.split(r"…|\.\.\.|\[\.\.\.\]", r["quote"]) if norm(s)]
    memo_pairs = sorted({(v, d) for v, d, t in quotes if all(s in norm(t) for s in segs)})
    flag = "MATCH" if tuple(r["pair"]) in memo_pairs else ("NOT IN MEMO LIST" if not memo_pairs else "MEMO PAIR DIFFERS")
    print(f"[{r['n']:02d}] cited {r['pair'][0]}/{r['pair'][1]}  memo Q pairs {memo_pairs}  -> {flag}")

# --- collection excerpts ---
print("\n=== COLLECTION EXCERPTS ===")
col = json.load(open(R + "/collection.fruscollection"))
ne = eok = ebad = 0
for e in col["entries"]:
    if e.get("kind") != "excerpt":
        continue
    ne += 1
    ok, why, offs = check(e["text"], e["volumeId"], e["documentId"])
    if ok: eok += 1
    else: ebad += 1
    print(f"{'OK  ' if ok else 'FAIL'} {e['volumeId']}/{e['documentId']} offs {offs} {why if not ok else ''}: {e['text'][:90]}")
print(f"excerpts {ne}: ok {eok} fail {ebad}")

# --- every excerpt belongs to a document entry with the same pair? ---
docpairs = {(e["volumeId"], e["documentId"]) for e in col["entries"] if e.get("kind") == "document"}
orphans = [(e["volumeId"], e["documentId"]) for e in col["entries"] if e.get("kind") == "excerpt" and (e["volumeId"], e["documentId"]) not in docpairs]
print("excerpts whose pair has no document entry:", orphans)
