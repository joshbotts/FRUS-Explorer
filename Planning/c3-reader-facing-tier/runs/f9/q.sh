#!/bin/zsh
# usage: q.sh "SQL"  -- logs then runs read-only
R=/Users/jbotts/frus-analysis/c3f/runs/f9
print -r -- "sqlite3 -readonly /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db \"$1\"" >> $R/queries.log
sqlite3 -readonly -separator '|' /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "$1"
