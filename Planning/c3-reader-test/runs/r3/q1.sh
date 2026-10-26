DB=/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db
M="$1"; N=${2:-30}
Q="SELECT d.volume_id||'/'||d.document_id, substr(replace(d.header,char(10),' '),1,90), length(d.body_text) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '$M' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') ORDER BY bm25(frus_documents) LIMIT $N;"
echo "$Q" >> /Users/jbotts/frus-analysis/c3/runs/r3/queries.log
sqlite3 -readonly $DB "$Q"
