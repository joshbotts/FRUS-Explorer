# Build collection.fruscollection from scripts/collection_docs.txt (finding, volume, document), the notes in
# scripts/collection_notes.json, the verified quotations in out/quotes_verified.json (only those listed in
# OVERVIEW_QUOTES are written as excerpts, after their document), and the texts below. Documents are ordered by
# date within each heading (date_iso from document_dates). Validates the contract before writing.
# SQL run: SELECT volume_id, document_id, date_iso FROM document_dates WHERE (volume_id, document_id) IN (VALUES ...);
#          SELECT COUNT(*) FROM document_cache WHERE volume_id=? AND document_id=?;  (existence check per pair)
import json, sqlite3, collections
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
RUN = "Agent run r10, 2026-10-25"
NOTE_PREFIX = "Agent finding, run r10, 2026-10-25: "
OVERVIEW_QUOTES = ["Q05", "Q13", "Q40", "Q02", "Q12", "Q16", "Q03", "Q10", "Q11", "Q18", "Q19", "Q21", "Q52", "Q24", "Q25", "Q28", "Q29", "Q32"]
spec = json.load(open(R + "scripts/collection_texts.json"))
rows = [l.rstrip("\n").split("\t") for l in open(R + "scripts/collection_docs.txt") if l.strip()]
notes = json.load(open(R + "scripts/collection_notes.json"))
quotes = {q["id"]: q for q in json.load(open(R + "out/quotes_verified.json"))}
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
pairs = [(v, d) for f, v, d in rows]
q = "SELECT volume_id, document_id, date_iso FROM document_dates WHERE (volume_id, document_id) IN (VALUES %s)" % ",".join(["(?,?)"] * len(pairs))
dates = {(v, d): di for v, d, di in con.execute(q, [x for p in pairs for x in p])}
by_f = collections.OrderedDict()
for f, v, d in rows:
    by_f.setdefault(f, []).append((dates.get((v, d)) or "", v, d))
qs_by_doc = collections.defaultdict(list)
for qid in OVERVIEW_QUOTES:
    qq = quotes[qid]
    assert qq["in_body_text"] and qq["in_TEI_document_text_not_notes"], qid
    qs_by_doc[(qq["volumeId"], qq["documentId"])].append(qq)
entries = []
for f in spec["order"]:
    entries.append({"kind": "heading", "text": spec["headings"][f], "level": 1})
    entries.append({"kind": "prose", "text": spec["prose"][f]})
    for di, v, d in sorted(by_f[f]):
        entries.append({"kind": "document", "volumeId": v, "documentId": d, "notes": [NOTE_PREFIX + notes["%s/%s" % (v, d)]]})
        for qq in qs_by_doc.get((v, d), []):
            entries.append({"kind": "excerpt", "volumeId": v, "documentId": d, "text": qq["text"]})
entries.append({"kind": "heading", "text": spec["closingHeading"], "level": 1})
entries.append({"kind": "prose", "text": spec["closingProse"]})
entries.append({"kind": "generated", "generatedBlockType": "archivalSources"})
coll = {"format": "fruscollection", "formatVersion": 2, "minimumReaderVersion": 1, "name": spec["name"], "authorLine": RUN,
        "introductionText": spec["introductionText"],
        "composition": {"defaultBodyDepth": "full", "footnoteStyle": "all", "includeSourceNote": True, "tocStyle": "citation",
                        "applyHighlights": False, "includeNotes": True, "includeWordCloud": False},
        "entries": entries}
# ---- validation ----
docs = [(e["volumeId"], e["documentId"]) for e in entries if e["kind"] == "document"]
assert len(docs) == len(set(docs)), "duplicate document pair"
for e in entries:
    if e["kind"] in ("document", "excerpt"):
        assert e.get("volumeId") and e.get("documentId"), e
        n = con.execute("SELECT COUNT(*) FROM document_cache WHERE volume_id=? AND document_id=?", (e["volumeId"], e["documentId"])).fetchone()[0]
        assert n == 1, e
    if e["kind"] == "excerpt":
        assert (e["volumeId"], e["documentId"]) in set(docs), "excerpt without its document"
    if e["kind"] == "document":
        assert all(nt.startswith(NOTE_PREFIX) for nt in e["notes"])
vols = {v for v, d in docs}
for ed2 in [v for v in vols if v.endswith("Ed2")]:
    assert ed2.replace("Ed2", "") not in vols, "Ed2 beside its first edition"
assert len(docs) == len(rows), (len(docs), len(rows))
assert sum(1 for e in entries if e["kind"] == "excerpt") == len(OVERVIEW_QUOTES)
json.dump(coll, open(R + "collection.fruscollection", "w"), ensure_ascii=False, indent=1)
print("documents:", len(docs), "excerpts:", sum(1 for e in entries if e["kind"] == "excerpt"), "headings:", sum(1 for e in entries if e["kind"] == "heading"),
      "prose:", sum(1 for e in entries if e["kind"] == "prose"), "entries:", len(entries))
