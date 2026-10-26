# usage: dump.sh vol/doc ... ; writes docs/vol__doc.txt and prints
DB=/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db
cd /Users/jbotts/frus-analysis/c3/runs/r3
for p in "$@"; do v=${p%%/*}; d=${p##*/}
Q="SELECT header||char(10)||coalesce(dateline,'')||char(10)||coalesce(source_note,'')||char(10)||body_text FROM document_cache WHERE volume_id='$v' AND document_id='$d';"
echo "dump.sh $p :: $Q" >> queries.log
sqlite3 -readonly $DB "$Q" > docs/${v}__${d}.txt
echo "##### $p ($(sqlite3 -readonly $DB "select length(body_text) from document_cache where volume_id='$v' and document_id='$d'") chars body)"; cat docs/${v}__${d}.txt
done
