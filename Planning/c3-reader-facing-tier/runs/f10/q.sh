#!/bin/zsh
# usage: q.sh "SQL"  -- logs then runs read-only
R=/Users/jbotts/frus-analysis/c3f/runs/f10
printf 'sqlite3 -readonly DB "%s"\n' "$1" >> $R/queries.log
sqlite3 -readonly -header -separator '|' /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "$1"
