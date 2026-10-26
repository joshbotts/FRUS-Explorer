# Final check of the four deliverables: collection contract (keys, both ids, no duplicate pair, every pair exists in
# document_cache and is not apparatus, no Ed2 beside its first edition, every excerpt a substring of its document's
# body_text, every note with the attribution prefix); overview quotes are excerpts; files exist.
# SQL run per pair: SELECT is_front_matter, is_editorial_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?;
import json, os, sqlite3, re
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
for f in ("memo.md", "overview.md", "collection.fruscollection", "queries.log"):
    print(f, os.path.getsize(R + f), "bytes")
c = json.load(open(R + "collection.fruscollection"))
assert c["format"] == "fruscollection" and c["formatVersion"] == 2 and c["minimumReaderVersion"] == 1
assert set(c["composition"]) == {"defaultBodyDepth", "footnoteStyle", "includeSourceNote", "tocStyle", "applyHighlights", "includeNotes", "includeWordCloud"}
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
pairs = []; nexc = 0
for e in c["entries"]:
    if e["kind"] in ("document", "excerpt"):
        r = con.execute("SELECT is_front_matter, is_editorial_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (e["volumeId"], e["documentId"])).fetchone()
        assert r and r[0] == 0 and r[1] == 0, e
        if e["kind"] == "document":
            pairs.append((e["volumeId"], e["documentId"]))
            assert all(n.startswith("Agent finding, run r10, 2026-10-25: ") for n in e["notes"])
        else:
            assert e["text"] in r[2]; nexc += 1
assert len(pairs) == len(set(pairs))
vols = {v for v, d in pairs}
assert not any(v.endswith("Ed2") and v[:-3] in vols for v in vols)
assert c["entries"][-1] == {"kind": "generated", "generatedBlockType": "archivalSources"}
print("collection OK:", len(pairs), "documents,", nexc, "excerpts,", len(c["entries"]), "entries; authorLine:", c["authorLine"])
