import re, json, sqlite3, sys
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s4/"
con = sqlite3.connect(DB, uri=True)

def norm(t):
    return re.sub(r"[^a-z0-9]", "", t.lower())

_cache = {}
def rowtext(v, d):
    if (v, d) not in _cache:
        r = con.execute("select header,coalesce(dateline,''),coalesce(source_note,''),body_text from document_cache where volume_id=? and document_id=?", (v, d)).fetchone()
        _cache[(v, d)] = None if r is None else norm("".join(r))
    return _cache[(v, d)]

def check(q, text):
    if text is None:
        return False
    segs = [norm(s) for s in re.split(r"…|\[\.\.\.\]|\.\.\.", q)]
    segs = [s for s in segs if s]
    pos = 0
    for s in segs:
        i = text.find(s, pos)
        if i < 0:
            return False
        pos = i + len(s)
    return True

# ---------- overview quotations ----------
s = open(RUN + "overview.md").read()
lines = s.split("\n")
qs = []
for ln, line in enumerate(lines, 1):
    for m in re.finditer(r"\"([^\"]{2,})\"|“([^”]{2,})”", line):
        q = m.group(1) or m.group(2)
        urls = re.findall(r"historicaldocuments/([^/\s)]+)/(d\d+)", line)
        qs.append((ln, q, urls))
print("double-quoted strings in overview.md:", len(qs))

TITLES = {0, 1, 2, 3, 14, 16, 18, 24, 26, 28, 34, 36, 38, 46, 48, 50, 56, 58, 60, 67, 69, 71, 74}
TERMS = {4, 5, 6, 7, 8, 9, 73, 75}

# memo trace rows, in order
memo = open(RUN + "memo.md").read()
trace = re.findall(r"^\| quotation: '(.*)' \| M6 row (\S+) \|", memo, re.M)
print("memo trace quotation rows:", len(trace))
tp = 0
results = []
fab = []; mis = []
for i, (ln, q, urls) in enumerate(qs):
    kind = "TITLE" if i in TITLES else ("TERM" if i in TERMS else "QUOTE")
    tpair = None
    # consume the next trace row if its prefix matches this quote
    if tp < len(trace):
        pref, pair = trace[tp]
        pref = pref[:-3] if pref.endswith("...") else pref
        if norm(q).startswith(norm(pref)) and norm(pref):
            tpair = pair; tp += 1
    if kind != "QUOTE":
        results.append((i, ln, kind, q[:80], tpair, None, None))
        continue
    v, d = tpair.split("/") if tpair else (None, None)
    ok = check(q, rowtext(v, d)) if tpair else False
    # the pair the overview itself credits on the same line (bullet lines carry a URL)
    credited = urls[0] if urls else None
    cred_ok = check(q, rowtext(*credited)) if credited else None
    results.append((i, ln, kind, q[:80], tpair, ok, (credited, cred_ok)))
    if not ok:
        fab.append((i, ln, q, tpair))
    if credited and tpair and f"{credited[0]}/{credited[1]}" != tpair:
        mis.append((i, ln, q, tpair, credited))
for r in results:
    print(r)
print("\nQUOTES failing the segment check against the memo's trace pair:", len(fab))
for f in fab: print("  FAIL:", f)
print("bullet-line quotes whose same-line URL differs from the trace pair:", len(mis))
for m in mis: print("  MIS:", m)
nq = sum(1 for r in results if r[2] == "QUOTE")
print("overview QUOTE count:", nq, "passed:", sum(1 for r in results if r[2] == "QUOTE" and r[5]))

# where the trace pair looks like an artifact (single words), test against every collection doc
coll = json.load(open(RUN + "collection.fruscollection"))
docs = [(e["volumeId"], e["documentId"]) for e in coll["entries"] if e["kind"] == "document"]
print("\nsingle-word / short quotes: which collection documents hold them")
for i, (ln, q, urls) in enumerate(qs):
    if i in TITLES or i in TERMS: continue
    if len(q) < 25:
        hits = [f"{v}/{d}" for v, d in docs if check(q, rowtext(v, d))]
        print(f"  [{i}] line {ln} '{q}': in", hits)

# ---------- collection excerpts ----------
ex = [e for e in coll["entries"] if e["kind"] == "excerpt"]
bad = 0
for e in ex:
    ok = check(e["text"], rowtext(e["volumeId"], e["documentId"]))
    if not ok:
        bad += 1; print("  EXCERPT FAIL:", e["volumeId"], e["documentId"], e["text"][:100])
print("\nexcerpts:", len(ex), "failing:", bad)

# ---------- printed citations: resolve each URL and compare with the text before it ----------
man = json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
vols = man["volumes"] if isinstance(man, dict) and "volumes" in man else man
titles = {}
for e in vols:
    vid = e.get("id") or e.get("volumeId") or e.get("volume_id")
    titles[vid] = e.get("title") or e.get("volumeTitle") or e.get("name")
print("\nmanifest volumes:", len(titles), "sample keys:", list(vols[0].keys())[:12])
cites = []
for ln, line in enumerate(lines, 1):
    for m in re.finditer(r"(.{0,230}?)\(?https://history\.state\.gov/historicaldocuments/([^/\s)]+)/(d\d+)\)?", line):
        cites.append((ln, m.group(1), m.group(2), m.group(3)))
print("URL citations in overview:", len(cites), "distinct pairs:", len({(c[2], c[3]) for c in cites}))
problems = 0
for ln, before, v, d in cites:
    r = con.execute("select header, document_number, dateline from document_cache where volume_id=? and document_id=?", (v, d)).fetchone()
    dt = con.execute("select date_iso from document_dates where volume_id=? and document_id=?", (v, d)).fetchone()
    hdr = re.sub(r"\s+", " ", r[0]) if r else None
    # the printed citation is the last quoted title or the text after the last ';' / 'Also cited'
    cite = before
    mdoc = re.search(r"Document (\d+)\b[^\d]*$", cite)
    note = ""
    if mdoc:
        n = mdoc.group(1)
        if r and (r[1] == n or d == "d" + n):
            note = "Document number OK"
        else:
            note = f"DOCUMENT NUMBER MISMATCH: printed {n}, row document_number={r[1] if r else None}"; problems += 1
    else:
        # header-and-date form: take the clause after the volume title
        mh = re.search(r"Volume [IVXLC]+[^,]*,\s*(.*?),\s*([A-Z][a-z]+ \d{1,2}, \d{4})\s*$", cite) or re.search(r"Appendix [IVX]+,\s*(.*?),\s*([A-Z][a-z]+ \d{1,2}, \d{4})\s*$", cite) or re.search(r"Appendix [IVX]+,\s*(Statement of [^\"]+)$", cite)
        if mh:
            ph = mh.group(1); pd = mh.group(2) if mh.lastindex and mh.lastindex >= 2 else None
            hok = norm(ph.replace("the ", "")) in norm(hdr or "") or norm(ph) in norm(hdr or "")
            dok = None
            if pd:
                import datetime
                try:
                    iso = datetime.datetime.strptime(pd, "%B %d, %Y").strftime("%Y-%m-%d")
                    dok = (dt[0] == iso) if dt else None
                except Exception:
                    dok = None
            note = f"header match={hok} date match={dok} (row date {dt[0] if dt else None})"
            if not hok or dok is False: problems += 1
        else:
            note = "no parse"
    # volume title check
    mv = re.search(r"((?:Papers Relating to the )?Foreign Relations of the United States, .*?(?:Volume [IVXLC–E0-9\-]+[^,]*|Appendix [IVX]+)(?:, Part \d+)?(?:, [^,]*?(?:Documents on [^,]*|Vietnam|Mexico, Cuba, and the Caribbean|South America; Latin America Region|Northeast Asia|Congo Crisis|Foreign Economic Policy|Vietnam, 19\d\d))?)", cite)
    mt = titles.get(v, "")
    print(f"line {ln} {v}/{d} | manifest: {mt[:90]} | row header: {(hdr or '')[:80]} | date {dt[0] if dt else None} | {note}")
    print(f"      printed: ...{cite[-150:]}")
print("printed-citation problems:", problems)

# ---------- collection notes: stated dates vs the index's dates ----------
MONTHS = {m: i for i, m in enumerate(["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], 1)}
print("\ncollection notes: stated date vs document_dates")
nd = 0
for e in coll["entries"]:
    if e["kind"] != "document": continue
    note = " ".join(e.get("notes") or [])
    m = re.search(r"(\d{1,2}) (January|February|March|April|May|June|July|August|September|October|November|December) (\d{4})", note)
    dt = con.execute("select date_iso from document_dates where volume_id=? and document_id=?", (e["volumeId"], e["documentId"])).fetchone()
    if m:
        iso = f"{m.group(3)}-{MONTHS[m.group(2)]:02d}-{int(m.group(1)):02d}"
        ok = dt and dt[0] == iso
        if not ok: nd += 1
        print(f"  {e['volumeId']}/{e['documentId']} note says {iso} index {dt[0] if dt else None} {'OK' if ok else 'MISMATCH'}")
    else:
        print(f"  {e['volumeId']}/{e['documentId']} note has no day date; index {dt[0] if dt else None} | {note[:80]}")
print("note-date mismatches:", nd)
