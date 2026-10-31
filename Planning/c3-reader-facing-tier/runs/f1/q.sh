#!/bin/zsh
# usage: q.sh "SQL"  -- logs and runs read-only
echo "sqlite3 -readonly DB \"$1\"" >> /Users/jbotts/frus-analysis/c3f/runs/f1/queries.log
sqlite3 -readonly /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "$1"
