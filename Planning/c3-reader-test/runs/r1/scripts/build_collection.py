# Build collection.fruscollection (format version 2) from the cited documents, their notes and the verified quotations; then verify it against the index.
import sys, json, re, csv
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import content as K
import frus

ov = open(K.RUN + "/overview.md").read()
# the three-part bottom line as plain text for the title page, with short citations
m = re.search(r"## The bottom line\n\n(.*?)\n\*\*Scope\.\*\*", ov, re.S)
bl = m.group(1)
for key in K.META:
    bl = bl.replace(K.full_cite(key), K.short_cite(key))
bl = bl.replace("**", "").replace("*", "")
paras = [p.strip() for p in bl.split("\n\n") if p.strip()]
assert len(paras) == 3, len(paras)
intro = "\n\n".join(paras)

order = {}
for key, r in K.META.items():
    order.setdefault(int(r["finding"]), []).append((r["date_iso"], key))
entries = []
for f in sorted(K.FINDINGS):
    title, prose = K.FINDINGS[f]
    entries.append({"kind": "heading", "text": title, "level": 1})
    entries.append({"kind": "prose", "text": prose})
    for di, key in sorted(order[f]):
        v, d = key.split("/")
        entries.append({"kind": "document", "volumeId": v, "documentId": d, "notes": ["%s %s" % (K.ATTR, K.NOTES[key])]})
        for qid in K.EXCERPT_AFTER.get(key, []):
            entries.append({"kind": "excerpt", "volumeId": v, "documentId": d, "text": K.QUOTES[qid]["text"]})
closing = ("Threads I could not follow. The editors gave chapters to cases I read only in part or not at all: Argentina in 1943–45 (about 120 documents under chapter titles that name recognition), Nicaragua in 1947 (40), Ecuador in 1944 and 1947 (37), Guatemala in 1944 (28), El Salvador in 1944–45 (48), Bolivia in 1946 (53), the Dominican Republic in 1916 (69), Mexico in 1920 (67 on the provisional government), and Paraguay and Bolivia in 1937 (83). Of the early 1950s I followed only Guatemala in June and July 1954, in two documents; I did not follow the rest of the Guatemalan record of 1954, the Bolivian cases of the early 1950s (where the editors’ chapter titles do not name recognition), the Nicaraguan case of 1979, the Bolivian cases of 1971 and 1980, or anything after 1980 beyond a count. I read 50 of the 2,255 documents that sit under chapters whose titles name recognition. I did not test whether governments complied with what they promised, and the pointed-at channel of footnote citations is nearly empty for the nineteenth century, so the Department’s own reasoning before 1920 is not in this collection.")
entries.append({"kind": "prose", "text": closing})
entries.append({"kind": "generated", "generatedBlockType": "archivalSources"})
doc = {
 "format": "fruscollection",
 "formatVersion": 2,
 "minimumReaderVersion": 1,
 "name": "Recognition of governments that came to power by force in Latin America — agent run, 25 October 2026",
 "authorLine": "Agent run, 25 October 2026",
 "introductionText": intro,
 "composition": {"defaultBodyDepth": "full", "footnoteStyle": "all", "includeSourceNote": True, "tocStyle": "citation", "applyHighlights": False, "includeNotes": True, "includeWordCloud": False},
 "entries": entries,
}
path = K.RUN + "/collection.fruscollection"
json.dump(doc, open(path, "w"), ensure_ascii=False, indent=2)
print("written:", path)

# ---- verification against the index (explicit SELECTs, logged)
conn = frus.connect()
back = json.load(open(path))
assert back["format"] == "fruscollection" and back["formatVersion"] == 2 and back["minimumReaderVersion"] == 1
assert set(back["composition"]) == {"defaultBodyDepth", "footnoteStyle", "includeSourceNote", "tocStyle", "applyHighlights", "includeNotes", "includeWordCloud"}
seen = set(); problems = []; ndoc = nex = 0
for e in back["entries"]:
    if e["kind"] in ("document", "excerpt"):
        v, d = e.get("volumeId"), e.get("documentId")
        if not v or not d:
            problems.append(("missing id", e)); continue
        if v.endswith("Ed2"):
            problems.append(("Ed2 volume", v))
        r = frus.sql(conn, "SELECT body_text, is_front_matter, is_editorial_note, document_number FROM document_cache WHERE volume_id = ? AND document_id = ?", (v, d), script="scripts/build_collection.py", log=(e["kind"] == "document" and ndoc == 0))
        if not r:
            problems.append(("not in document_cache", v, d)); continue
        body = r[0][0]
        if e["kind"] == "document":
            ndoc += 1
            if (v, d) in seen: problems.append(("duplicate", v, d))
            seen.add((v, d))
            if r[0][1] or r[0][2] or not r[0][3]: problems.append(("apparatus or unnumbered", v, d))
            for n in e["notes"]:
                if not n.startswith("Agent finding, research run of 2026-10-25:"): problems.append(("note without attribution", v, d))
        else:
            nex += 1
            if e["text"] not in body: problems.append(("excerpt not found verbatim", v, d, e["text"][:60]))
print("documents:", ndoc, "excerpts:", nex, "problems:", problems)
print("introductionText characters:", len(back["introductionText"]))
