#!/bin/bash
# Usage: sq.sh "SQL"  -- logs the exact sqlite3 command (newlines collapsed) to queries.log, then runs it read-only.
DB=/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db
LOG=/Users/jbotts/frus-analysis/c3/runs/r2/queries.log
SQL="$1"
ONE=$(printf '%s' "$SQL" | tr '\n' ' ' | sed 's/  */ /g')
printf 'sqlite3 -readonly %s "%s"\n' "$DB" "$ONE" >> "$LOG"
sqlite3 -readonly -header -separator '|' "$DB" "$SQL"
