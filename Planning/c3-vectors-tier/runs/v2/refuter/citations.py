# Resolve every printed citation in the overview through manifest.json and document_cache.document_number; check the identity
# of frus1898/ch83; read the speaker context of Q13 and Q10; find the editors' heading quoted in finding 4.
import sqlite3, json, re
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
man = {v["volumeId"]: v for v in json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))}
ov = open("/Users/jbotts/frus-analysis/c3v/runs/v2/overview.md").read()
urls = re.findall(r"historicaldocuments/([^/\s)]+)/([^\s)]+)", ov)
print("URL citations in overview:", len(urls), "distinct", len(set(urls)))
for v, d in sorted(set(urls)):
    r = db.execute("SELECT document_number, header, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    print(f"  {v}/{d}: in document_cache={r is not None}; number={r[0] if r else None}; fm/en={(r[2], r[3]) if r else None}; manifest title={' '.join(man[v]['title'].split())[:110] if v in man else 'NOT IN MANIFEST'}")
print("\n== printed citations without a URL (bottom line):")
for lab, v, d, num in [("1902, Document 313","frus1902","d313",313),("1903, Document 331","frus1903","d331",331),("1906, Part I, Document 427","frus1906p1","d427",427),("1933, Volume V, Document 281","frus1933v05","d281",281),("1952–1954, Volume IV, Document 343","frus1952-54v04","d343",343),("1961–1963, Volume X, Document 202","frus1961-63v10","d202",202),("Volume XI, Document 34","frus1961-63v11","d34",34),("1969–1976, Volume E–10, Document 205","frus1969-76ve10","d205",205),("Volume XII, Document 211","frus1969-76v12","d211",211),("1977–1980, Volume XXIII, Documents 21 and 98","frus1977-80v23","d21",21),("(same) Document 98","frus1977-80v23","d98",98),("1870, Document 197","frus1870","d197",197),("1881, Document 405","frus1881","d405",405),("1898, Document 490","frus1898","d490",490)]:
    r = db.execute("SELECT document_number FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    print(f"  {lab!r} -> {v}/{d}: document_number={r[0] if r else None} match={bool(r and str(r[0])==str(num))}; title={' '.join(man[v]['title'].split())[:80]}")
print("\n== frus1898/ch83 identity")
h, dl, body = db.execute("SELECT header, dateline, body_text FROM document_cache WHERE volume_id='frus1898' AND document_id='ch83'").fetchone()
print("  header:", repr(h), "| dateline:", repr(dl)); print("  body head:", repr(body[:300]))
for needle in ["April 11, 1898", "WILLIAM McKINLEY", "William McKinley", "McKinley", "Executive Mansion"]:
    i = body.find(needle); print(f"  {needle!r} at {i}: {body[max(0,i-80):i+60]!r}" if i >= 0 else f"  {needle!r} NOT FOUND")
print("\n== Q13 context (frus1961-63v11/d34): 'In his view the existence of fifty planes'")
body = db.execute("SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v11' AND document_id='d34'").fetchone()[0]
i = body.find("In his view the existence of fifty planes"); print(repr(body[i-700:i+200]))
print("\n== Q10 context (frus1941v07/d119): 'nevertheless essential'")
body = db.execute("SELECT body_text FROM document_cache WHERE volume_id='frus1941v07' AND document_id='d119'").fetchone()[0]
i = body.find("nevertheless essential"); print(repr(body[max(0,i-900):i+200]))
print("\n== Q1 signature (frus1870/d197)")
h, body = db.execute("SELECT header, body_text FROM document_cache WHERE volume_id='frus1870' AND document_id='d197'").fetchone()
print("  header:", repr(h)); print("  tail:", repr(body[-300:]))
print("\n== editors' heading quoted in finding 4 ('a policy to weaken the Cuban economy')")
for v, js in db.execute("SELECT volume_id, structure_json FROM volume_structures WHERE volume_id GLOB 'frus1958-60*'"):
    def walk(s, path):
        t = (s.get("title") or "").strip()
        if "weaken" in t.lower(): print("  ", v, " > ".join(path + [t]), "docs", len(s.get("documentIds", [])))
        for x in s.get("subsections", []): walk(x, path + [t])
    for s in json.loads(js).get("sections", []): walk(s, [])
print("\n== d211 header / d205 header / d21 header")
for v, d in [("frus1969-76v12","d211"),("frus1969-76ve10","d205"),("frus1977-80v23","d21"),("frus1977-80v23","d98"),("frus1961-63v10","d202")]:
    print("  ", v, d, repr(db.execute("SELECT header FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()[0][:160]))
