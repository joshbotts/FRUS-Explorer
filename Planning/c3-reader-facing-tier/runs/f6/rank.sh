#!/bin/zsh
# usage: rank.sh 'FTS query' N [IN-list-file]
DB=/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db
IN=$(cat ${3:-/Users/jbotts/frus-analysis/c3f/runs/f6/eap_in.txt})
sqlite3 -readonly $DB "SELECT d.volume_id||'/'||d.document_id, round(bm25(frus_documents),1), length(d.body_text), substr(replace(replace(d.header,char(10),' '),'  ',' '),1,140) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '$1' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ($IN) ORDER BY bm25(frus_documents) LIMIT ${2:-40};"
