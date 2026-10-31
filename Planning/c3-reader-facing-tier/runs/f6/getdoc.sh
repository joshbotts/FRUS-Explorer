#!/bin/zsh
# usage: getdoc.sh volume_id document_id -> docs/<vol>__<doc>.txt (header, dateline, source_note, body); prints char length captured vs length(body_text)
DB=/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db
V=$1; D=$2
OUT=/Users/jbotts/frus-analysis/c3f/runs/f6/docs/${V}__${D}.txt
sqlite3 -readonly $DB "SELECT header||char(10)||'DATELINE: '||ifnull(dateline,'')||char(10)||'SOURCE: '||ifnull(source_note,'')||char(10)||'-----'||char(10)||body_text FROM document_cache WHERE volume_id='$V' AND document_id='$D';" > $OUT
echo "$V/$D file_chars=$(python3 -c "import sys;print(len(open(sys.argv[1],encoding='utf8').read()))" $OUT) body_len=$(sqlite3 -readonly $DB "SELECT length(body_text) FROM document_cache WHERE volume_id='$V' AND document_id='$D'")"
