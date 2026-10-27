import json, sqlite3, sys
path, db = sys.argv[1], sys.argv[2]        # the .fruscollection, and the index it was written from
c, problems = json.load(open(path)), []
if not path.endswith(".fruscollection"): problems.append("extension is not .fruscollection")
v = c.get("minimumReaderVersion")          # §15.3: the gate is this floor, else formatVersion,
if v is None: v = c.get("formatVersion")   # and the app opens a file whose gate is 2 or less
if c.get("format") != "fruscollection" or type(c.get("formatVersion")) is not int \
        or type(v) is not int or v > 2: problems.append("format gate (§15.3)")
missing = {"defaultBodyDepth", "footnoteStyle", "tocStyle", "applyHighlights", "includeNotes",
           "includeWordCloud"} - set(c.get("composition", {}))
if missing: problems.append(f"composition keys missing: {sorted(missing)}")
docs = [e for e in c.get("entries", []) if e.get("kind") == "document"]
pairs = [(e.get("volumeId") or "", e.get("documentId") or "") for e in docs]
if any(not v or not d for v, d in pairs): problems.append("an entry lacks volumeId or documentId")
if len(pairs) != len(set(pairs)): problems.append(f"{len(pairs) - len(set(pairs))} duplicate pairs")
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
known = set(con.execute("SELECT volume_id, document_id FROM document_cache"))
absent = [p for p in pairs if p not in known]
if absent: problems.append(f"{len(absent)} pairs not in document_cache, e.g. {absent[:3]}")
vols = {v for v, _ in known}
twins = sorted({v for v, _ in pairs if v.endswith("Ed2") and v[:-3] in vols})
if twins: problems.append(f"Ed2 beside its first edition (§14.9): {twins}")
print(len(docs), "documents;", "; ".join(problems) or "all checks pass")
sys.exit(1 if problems else 0)
