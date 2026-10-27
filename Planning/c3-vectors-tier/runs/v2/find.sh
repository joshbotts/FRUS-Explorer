#!/bin/zsh
# usage: find.sh '<fts match>' '<volume glob>' [limit]
sqlite3 -readonly /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "SELECT c.volume_id||'/'||c.document_id, d.date_iso, length(c.body_text), substr(replace(c.header,char(10),' '),1,110) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE frus_documents MATCH '$1' AND c.volume_id GLOB '$2' AND c.is_front_matter=0 AND c.is_editorial_note=0 ORDER BY bm25(frus_documents) LIMIT ${3:-8};"
