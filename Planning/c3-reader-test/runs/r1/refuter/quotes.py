#!/usr/bin/env python3 -I
"""Refuter: the quotation check for cell r1.
Lists every passage inside quotation marks or set as a block quote in overview.md and every
excerpt in collection.fruscollection; resolves each attribution to a (volume_id, document_id)
pair from the citation's URL, cross-checks the printed title/volume against manifest.json and
the memo's section-17 table; then applies the guide's rule: lower-case, keep [a-z0-9], split at
ellipses, every segment in order at increasing offsets in header||dateline||source_note||body_text
of the exact pair."""
import re, json, sqlite3, unicodedata, sys

RUN = "/Users/jbotts/frus-analysis/c3/runs/r1"
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)

def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())

def norm_ascii(s):
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    return norm(s)

ELL = re.compile(r"\.\.\.|…|\[\.\.\.\]|\[…\]")

def check(quote, vol, doc, normf=norm):
    row = con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (vol, doc)).fetchone()
    if row is None:
        return False, "pair not in document_cache", []
    hay = normf("".join(x or "" for x in row))
    segs = [s for s in ELL.split(quote) if normf(s)]
    pos = 0
    offsets = []
    for s in segs:
        ns = normf(s)
        i = hay.find(ns, pos)
        if i < 0:
            return False, f"segment not found at/after offset {pos}: {s[:60]!r}", offsets
        offsets.append(i)
        pos = i + len(ns)
    return True, f"{len(segs)} segment(s) found in order", offsets

# ---- manifest titles
man = json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
title = {v["volumeId"]: re.sub(r"\s+", " ", v["title"]).strip() for v in man}

# ---- memo section 17 table: printed citation -> pair
memo = open(f"{RUN}/memo.md", encoding="utf-8").read()
sec17 = {}
for m in re.finditer(r"^\| (\d) \| (frus[^ ]+)/(d[^ ]+) \| (.+?) \| (\d{4}-\d{2}-\d{2}) \| (\S*) \| (quoted|cited) \|$", memo, re.M):
    sec17[m.group(4).strip()] = (m.group(2), m.group(3), m.group(7), m.group(1))
print("memo section 17 rows:", len(sec17))
# memo Q labels
qlab = {}
for m in re.finditer(r"^- \[(Q\d\d)\] (frus[^/]+)/(d\d+) \((\d+) characters, finding (\d)\): “(.+)”\s*$", memo, re.M):
    qlab[m.group(1)] = (m.group(2), m.group(3), int(m.group(4)), m.group(6))
print("memo Q labels:", sorted(qlab))

# ---- overview block quotes
ov = open(f"{RUN}/overview.md", encoding="utf-8").read().split("\n")
blocks = []
i = 0
while i < len(ov):
    ln = ov[i]
    if ln.startswith("> ") and not ln.startswith("> —"):
        text = ln[2:].strip()
        # look ahead for the attribution
        j = i + 1
        cite = None
        while j < len(ov) and ov[j].startswith(">"):
            if ov[j].startswith("> —"):
                cite = ov[j][3:].strip()
            j += 1
        # the prose line before the block (the overview's lead-in)
        k = i - 1
        while k >= 0 and not ov[k].strip(): k -= 1
        blocks.append({"line": i + 1, "text": text, "cite": cite, "lead": ov[k].strip()[:90]})
        i = j
    else:
        i += 1
print("\nblock quotes in overview:", len(blocks))

# ---- every passage inside “ ” in the overview prose (outside block quotes)
inline = []
for n, ln in enumerate(ov, 1):
    if ln.startswith(">"): continue
    for m in re.finditer(r"“([^”]+)”", ln):
        inline.append((n, m.group(1)))
print("inline “…” passages in overview prose:", len(inline))
for n, t in inline: print(f"   line {n}: “{t}”")

# ---- resolve each block quote's attribution
def resolve(cite):
    m = re.search(r"https://history\.state\.gov/historicaldocuments/([^/\s]+)/(d\d+)", cite or "")
    url_pair = (m.group(1), m.group(2)) if m else None
    printed = re.sub(r",\s*https://\S+$", "", cite or "").strip()
    memo_pair = sec17.get(printed)
    m2 = re.search(r"Document (\d+)$", printed)
    docnum = m2.group(1) if m2 else None
    return url_pair, printed, memo_pair, docnum

fab = []; mis = []; ok = 0
print("\n=== OVERVIEW BLOCK QUOTES ===")
for b in blocks:
    url_pair, printed, memo_pair, docnum = resolve(b["cite"])
    vol, doc = url_pair
    # title check: printed citation's volume part vs manifest title
    vt = title.get(vol, "")
    printed_vol = re.sub(r", Document \d+$", "", printed)
    # the conventional shortening: "Papers Relating to the Foreign Relations of the United States, 1900"
    short_ok = False
    if printed_vol == vt:
        short_ok = True
    else:
        y = re.search(r"\b(1[89]\d\d)\b", printed_vol)
        if y and vt.startswith("Papers Relating to the Foreign Relations of the United States") and y.group(1) in vt and re.fullmatch(r"Papers Relating to the Foreign Relations of the United States, \d{4}", printed_vol):
            short_ok = "shortened"
    # document number check
    dn = con.execute("SELECT document_number FROM document_cache WHERE volume_id=? AND document_id=?", (vol, doc)).fetchone()
    dn = dn[0] if dn else None
    # memo label match
    lab = [k for k, v in qlab.items() if v[0] == vol and v[1] == doc and norm(v[3]) == norm(b["text"].strip("“”"))]
    passed, why, offs = check(b["text"].strip("“”"), vol, doc)
    passed_ascii = check(b["text"].strip("“”"), vol, doc, norm_ascii)[0]
    status = "OK" if passed else "FABRICATION?"
    cite_ok = (memo_pair is None or (memo_pair[0], memo_pair[1]) == url_pair) and (dn == docnum)
    if not cite_ok: status += " MISCITATION?"
    print(f"\n[{status}] overview line {b['line']} -> {vol}/{doc} (memo {lab or 'NO LABEL'}; memo table {memo_pair[:2] if memo_pair else 'not in table'}; document_number={dn} printed Document {docnum}; title {'exact' if short_ok is True else short_ok or 'MISMATCH: '+vt[:70]})")
    print(f"   lead: {b['lead']}")
    print(f"   text ({len(b['text'])} chars): {b['text'][:110]}...")
    print(f"   check: {why}; offsets {offs}; accent-insensitive variant: {passed_ascii}")
    if passed and cite_ok: ok += 1
    if not passed: fab.append((b["line"], vol, doc, why))
    if not cite_ok: mis.append((b["line"], vol, doc, printed, memo_pair))

print(f"\nblock quotes: {len(blocks)}; passed check and citation: {ok}; fabrications: {len(fab)}; mis-citations: {len(mis)}")

# ---- collection excerpts
c = json.load(open(f"{RUN}/collection.fruscollection"))
ex = [e for e in c["entries"] if e.get("kind") == "excerpt"]
print(f"\n=== COLLECTION EXCERPTS: {len(ex)} ===")
exok = 0; exfab = []
ovtexts = {norm(b["text"].strip("“”")): (b["line"], resolve(b["cite"])[0]) for b in blocks}
for e in ex:
    passed, why, offs = check(e["text"], e["volumeId"], e["documentId"])
    passed_ascii = check(e["text"], e["volumeId"], e["documentId"], norm_ascii)[0]
    # which overview block quote is it, and is the pair the same?
    ovm = ovtexts.get(norm(e["text"]))
    same = ovm is not None and ovm[1] == (e["volumeId"], e["documentId"])
    # does the collection hold the document entry for this pair?
    has_doc = any(d.get("kind") == "document" and d.get("volumeId") == e["volumeId"] and d.get("documentId") == e["documentId"] for d in c["entries"])
    print(f"[{'OK' if passed else 'FABRICATION?'}] {e['volumeId']}/{e['documentId']} ({len(e['text'])} chars) {why}; offsets {offs}; accent-insensitive {passed_ascii}; = overview block at line {ovm[0] if ovm else None} same pair {same}; document entry present {has_doc}")
    print(f"   {e['text'][:100]}...")
    if passed: exok += 1
    else: exfab.append((e["volumeId"], e["documentId"], why))
print(f"\nexcerpts: {len(ex)}; passed: {exok}; failed: {len(exfab)}")

# ---- the memo's Q list vs the overview's block quotes vs the excerpts (all three should agree)
qset = {(v[0], v[1], norm(v[3])) for v in qlab.values()}
bset = {(resolve(b['cite'])[0][0], resolve(b['cite'])[0][1], norm(b['text'].strip('“”'))) for b in blocks}
eset = {(e['volumeId'], e['documentId'], norm(e['text'])) for e in ex}
print("\nmemo Q set == overview block set:", qset == bset, "| overview block set == excerpt set:", bset == eset)
if qset != bset: print("  memo-only:", [q for q in qset if q not in bset][:5], " overview-only:", [q for q in bset if q not in qset][:5])
if bset != eset: print("  overview-only:", [q for q in bset if q not in eset][:5], " excerpt-only:", [q for q in eset if q not in bset][:5])
# the memo's character counts
for k, v in sorted(qlab.items()):
    if len(v[3]) != v[2]: print(f"  memo {k}: states {v[2]} characters, text has {len(v[3])}")
