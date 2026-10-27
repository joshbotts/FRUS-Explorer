# Check collection.fruscollection: format keys, both ids on every document/excerpt, no duplicate document pair, every pair in
# document_cache (SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?), no Ed2, every excerpt an exact substring of
# body_text, and every overview-cited URL pair present as a document entry.
import json, sqlite3, re
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
C = json.load(open("collection.fruscollection"))
assert C["format"] == "fruscollection" and C["formatVersion"] == 2 and C["minimumReaderVersion"] == 1
assert set(C["composition"]) == {"defaultBodyDepth", "footnoteStyle", "includeSourceNote", "tocStyle", "applyHighlights", "includeNotes", "includeWordCloud"}
docs = [(e["volumeId"], e["documentId"]) for e in C["entries"] if e["kind"] == "document"]
assert len(docs) == len(set(docs)), "duplicate"
for e in C["entries"]:
    if e["kind"] in ("document", "excerpt"):
        assert e.get("volumeId") and e.get("documentId"); assert not e["volumeId"].endswith("Ed2")
        assert db.execute("SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?", (e["volumeId"], e["documentId"])).fetchone()
    if e["kind"] == "excerpt":
        b = db.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?", (e["volumeId"], e["documentId"])).fetchone()[0]
        assert e["text"] in b, e["text"][:50]
    if e["kind"] == "document": assert e["notes"][0].startswith("Agent run v2, 2026-10-26:")
cited = set(re.findall(r"historicaldocuments/([^/\s)]+)/([^\s)]+)", open("overview.md").read()))
missing = cited - set(docs)
print("documents", len(docs), "excerpts", sum(e["kind"] == "excerpt" for e in C["entries"]), "overview-cited pairs", len(cited), "missing from collection", sorted(missing), "collection docs not cited", sorted(set(docs) - cited))
print("last entry", C["entries"][-1])
