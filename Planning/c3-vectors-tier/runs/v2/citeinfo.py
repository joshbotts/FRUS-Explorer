# Citation facts for the 16 cited documents: document_number, date_iso, header, document_sources row; manifest title.
# SELECT c.document_number, d.date_iso, c.header, s.repository, s.record_group, s.lot_file, s.series_name, s.citation_era, s.decimal_class
# FROM document_cache c LEFT JOIN document_dates d ON (both keys) LEFT JOIN document_sources s ON (both keys) WHERE c.volume_id=? AND c.document_id=?
import sqlite3, json
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
man = {v["volumeId"]: " ".join(v["title"].split()) for v in json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))}
seen = []
for v, d, q in json.load(open("quotes.json")):
    if (v, d) in seen: continue
    seen.append((v, d))
    r = db.execute("""SELECT c.document_number, d.date_iso, c.header, s.repository, s.record_group, s.lot_file, s.series_name, s.citation_era, s.decimal_class
      FROM document_cache c LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
      LEFT JOIN document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?""", (v, d)).fetchone()
    print(f"{v}/{d} | num={r[0]} | {r[1]} | {r[2][:90]} | src={r[3:]} | {man.get(v)}")
