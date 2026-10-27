# The guide's quotation check: lower-case, keep [a-z0-9], split at ellipses, every segment in order at increasing offsets in
# header||dateline||source_note||body_text of the EXACT pair. Applied to (1) every "..." span in overview.md, (2) every excerpt in the collection.
import sqlite3, json, re
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
def norm(s): return re.sub(r"[^a-z0-9]", "", s.lower())
def segs(q): return [norm(x) for x in re.split(r"…|\[\.\.\.\]|\.\.\.", q) if norm(x)]
cache = {}
def surface(v, d):
    if (v, d) not in cache:
        r = db.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
        cache[(v, d)] = None if r is None else norm("".join(x or "" for x in r))
    return cache[(v, d)]
def check(q, v, d):
    s = surface(v, d)
    if s is None: return "NO SUCH ROW"
    pos = 0
    for seg in segs(q):
        i = s.find(seg, pos)
        if i < 0: return False
        pos = i + len(seg)
    return True
cited = [("frus1870","d197"),("frus1881","d405"),("frus1898","d490"),("frus1898","ch83"),("frus1902","d313"),("frus1903","d331"),("frus1906p1","d427"),("frus1933v05","d281"),("frus1941v07","d119"),("frus1952-54v04","d343"),("frus1961-63v10","d202"),("frus1961-63v11","d34"),("frus1969-76ve10","d205"),("frus1969-76v12","d211"),("frus1977-80v23","d21"),("frus1977-80v23","d98")]
print("=== (1) every double-quoted span in overview.md, with the pairs among the 16 cited that contain it ===")
text = open("/Users/jbotts/frus-analysis/c3v/runs/v2/overview.md").read()
spans = re.findall(r'"([^"]+)"', text)
print("spans found:", len(spans))
for i, q in enumerate(spans, 1):
    hits = ["/".join(p) for p in cited if check(q, *p) is True]
    print(f"[{i}] {q[:95]!r}\n     found in: {hits if hits else 'NONE of the 16'}")
print("\n=== (2) every excerpt in the collection against its own pair ===")
C = json.load(open("/Users/jbotts/frus-analysis/c3v/runs/v2/collection.fruscollection"))
ex = [e for e in C["entries"] if e["kind"] == "excerpt"]
ok = 0
for e in ex:
    r = check(e["text"], e["volumeId"], e["documentId"]); ok += (r is True)
    print(f"{e['volumeId']}/{e['documentId']}\t{r}\t{e['text'][:70]}")
print("excerpts", len(ex), "pass", ok)
print("\n=== (3) collection prose single-quoted fragments (not required) ===")
for e in C["entries"]:
    if e["kind"] == "prose":
        for q in re.findall(r"'([^']+)'", e["text"]):
            print(repr(q), [ "/".join(p) for p in cited if check(q, *p) is True])
