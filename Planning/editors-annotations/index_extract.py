#!/usr/bin/env python3
# Per-volume figures read from a copy of the app's index (2026-11-06).
# argv: <frus.db copy> <manifest.json> <out.json>
# Opens the copy read-only (`?mode=ro`); never the live store. The copy measured was made on
# 2026-11-04 from the Mac app's container with the app not running: `cp` of frus.db and its -wal,
# then `PRAGMA wal_checkpoint(TRUNCATE); PRAGMA journal_mode=DELETE` on the copy. Index version 71,
# 553 volumes. Every count is over `document_cache` rows with is_front_matter = 0.
#   docs            rows
#   people_docs     rows with a person_mentions row whose ref resolves to a persons row of the
#                   same volume: the rule the People browser and Person analytics read
#   persons_rows    persons rows (a borrowed split-set list counts as the borrower's own)
#   numbered        rows whose stored header opens with a printed number ("12. ")
#   despatch        rows with a despatch_serial (#965)
#   classified      rows with a non-empty document_sources.classification
import json, re, sqlite3, sys

def main():
    db_path, manifest, out = sys.argv[1:4]
    db = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    vols = [v["volumeId"] for v in json.load(open(manifest))]
    res = {v: dict(docs=0, people_docs=0, persons_rows=0, numbered=0, despatch=0, classified=0)
           for v in vols}
    num = re.compile(r"^\s*\d+[A-Za-z]?\.\s")
    for vid, header, serial in db.execute(
            "SELECT volume_id, header, despatch_serial FROM document_cache WHERE is_front_matter = 0"):
        if vid not in res: continue
        r = res[vid]; r["docs"] += 1
        if header and num.match(header): r["numbered"] += 1
        if serial: r["despatch"] += 1
    for vid, n in db.execute("""
            SELECT pm.volume_id, COUNT(DISTINCT pm.document_id)
            FROM person_mentions pm
            JOIN persons p ON p.volume_id = pm.volume_id AND p.ref = pm.person_ref
            JOIN document_cache d ON d.volume_id = pm.volume_id AND d.document_id = pm.document_id
                                 AND d.is_front_matter = 0
            GROUP BY 1"""):
        if vid in res: res[vid]["people_docs"] = n
    for vid, n in db.execute("SELECT volume_id, COUNT(*) FROM persons GROUP BY 1"):
        if vid in res: res[vid]["persons_rows"] = n
    for vid, n in db.execute("""
            SELECT ds.volume_id, COUNT(DISTINCT ds.document_id) FROM document_sources ds
            JOIN document_cache d ON d.volume_id = ds.volume_id AND d.document_id = ds.document_id
                                 AND d.is_front_matter = 0
            WHERE ds.classification IS NOT NULL AND TRIM(ds.classification) <> ''
            GROUP BY 1"""):
        if vid in res: res[vid]["classified"] = n
    indexed = db.execute("SELECT COUNT(DISTINCT volume_id) FROM document_cache").fetchone()[0]
    json.dump(dict(indexed_volumes=indexed, volumes=res), open(out, "w"), indent=0, sort_keys=True)
    print("volumes", len(res), "indexed", indexed)

if __name__ == "__main__":
    main()
