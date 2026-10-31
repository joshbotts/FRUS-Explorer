#!/usr/bin/env python3
# Refuter: segment-strict quotation check for every quoted passage in overview.md and every excerpt in the collection,
# against header || dateline || source_note || body_text of the EXACT cited pair; plus citation resolution. Read-only.
import sqlite3, re, json
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con = sqlite3.connect(DB, uri=True)
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s6/"
ov = open(RUN + "overview.md", encoding="utf-8").read()

def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())
def segments(q):
    parts = re.split(r"\[\.\.\.\]|\.\.\.|…", q)
    return [norm(p) for p in parts if norm(p)]
_cache = {}
def doc_text(v, d):
    if (v, d) not in _cache:
        r = con.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
        _cache[(v, d)] = None if r is None else norm("".join(x or "" for x in r))
    return _cache[(v, d)]
def check(q, v, d):
    t = doc_text(v, d)
    if t is None: return "NO SUCH ROW"
    pos = 0; found = []
    for seg in segments(q):
        i = t.find(seg, pos)
        if i < 0: return "NOT FOUND (segment %r...)" % seg[:40]
        found.append(i); pos = i + len(seg)
    # count occurrences of the whole (single-segment) quote
    occ = t.count(segments(q)[0]) if len(segments(q)) == 1 else None
    return "found at %s%s" % (found, "" if occ is None else " (occurrences %d)" % occ)

# Every passage in quotation marks in overview.md, with the pair the overview's own adjacent citation (URL) gives.
# Extracted programmatically below: each quoted passage is paired with the FIRST history.state.gov URL that follows it in the text.
quoted = []
for m in re.finditer(r"“([^”]+)”|\"([^\"]+)\"", ov):
    q = m.group(1) or m.group(2)
    after = ov[m.end():]
    u = re.search(r"https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)", after)
    # the citation must be in the same paragraph to count as the overview's attribution
    para_end = after.find("\n")
    same_para = u is not None and (para_end < 0 or u.start() < para_end)
    quoted.append((q, (u.group(1), u.group(2)) if same_para else None, m.start()))
print("== quoted passages in overview.md:", len(quoted))
SEARCH_TERMS = {"Department of State", "Church", "multinational", "presents to", "Corruption and U.S. diplomacy (agent run s6)"}
n_doc = 0; n_ok = 0
for q, pair, pos in quoted:
    if q in SEARCH_TERMS:
        print("  [search term / name, not a document quotation] %r" % q); continue
    n_doc += 1
    res = check(q, *pair) if pair else "NO CITATION IN PARAGRAPH"
    ok = res.startswith("found")
    n_ok += ok
    print("  %s | %s/%s | %r" % ("OK " if ok else "FAIL", pair[0] if pair else "?", pair[1] if pair else "?", q[:90]), "|", res)
print("document-attributed quotations:", n_doc, "| verified in the cited pair:", n_ok)

print()
print("== collection excerpts")
c = json.load(open(RUN + "collection.fruscollection"))
ex = [e for e in c["entries"] if e["kind"] == "excerpt"]
eok = 0
for e in ex:
    res = check(e["text"], e["volumeId"], e["documentId"]); ok = res.startswith("found"); eok += ok
    print("  %s | %s/%s | %r | %s" % ("OK " if ok else "FAIL", e["volumeId"], e["documentId"], e["text"][:70], res))
print("excerpts:", len(ex), "| verified:", eok)

print()
print("== citation resolution: printed edition citation vs URL pair (manifest title + document number)")
man = {v["volumeId"]: v for v in json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))}
def ws(s): return re.sub(r"\s+", " ", s).strip()
cites = re.findall(r"\((Foreign Relations of the United States[^()]*?(?:\([^()]*\)[^()]*?)*?)\s*\((https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+))\)", ov)
print("edition citations with URL:", len(cites))
bad = 0
seen = set()
for printed, url, v, d in cites:
    key = (printed, v, d)
    if key in seen: continue
    seen.add(key)
    title = ws(man[v]["title"]) if v in man else "NOT IN MANIFEST"
    row = con.execute("SELECT document_number, header FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    mdoc = re.search(r"Document (\d+)$", printed.strip())
    mno = re.search(r"(No\. \d+)", printed)
    problems = []
    if not printed.startswith(title): problems.append("title mismatch: manifest=%r" % title)
    if row is None: problems.append("no such row")
    else:
        dn, hdr = row
        if mdoc and str(dn) != mdoc.group(1): problems.append("document_number=%r vs printed %s" % (dn, mdoc.group(1)))
        if mno and not hdr.startswith(mno.group(1)): problems.append("header %r vs printed %s" % (hdr[:40], mno.group(1)))
        if not mdoc and not mno: problems.append("no document number in printed citation")
    bad += bool(problems)
    print("  %s %s/%s | %s | %s" % ("OK " if not problems else "BAD", v, d, printed[:95], "; ".join(problems) or ("doc_number=%s" % (row[0] if row else None))))
print("citations with a problem:", bad)
