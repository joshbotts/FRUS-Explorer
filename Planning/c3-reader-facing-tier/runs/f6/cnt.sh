#!/bin/zsh
# usage: cnt.sh 'FTS query'  -> counts docs in EAP volumes, non-apparatus
DB=/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db
IN=$(cat /Users/jbotts/frus-analysis/c3f/runs/f6/eap_in.txt)
sqlite3 -readonly $DB "SELECT '$1', COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '$1' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ($IN);"
