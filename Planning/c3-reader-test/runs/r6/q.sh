#!/bin/zsh
# usage: q.sh "SQL"  -- logs the SQL as one line to queries.log, runs it read-only
L=/Users/jbotts/frus-analysis/c3/runs/r6/queries.log
print -r -- "q.sh: sqlite3 -readonly DB \"$(print -r -- "$1" | tr '\n' ' ')\"" >> $L
sqlite3 -readonly -separator '|' /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "$1"
