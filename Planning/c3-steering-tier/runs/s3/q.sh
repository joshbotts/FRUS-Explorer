#!/bin/zsh
# q.sh "SQL" : logs the sql then runs it read-only
echo "sqlite3 -readonly DB \"$1\"" | tr '\n' ' ' >> /Users/jbotts/frus-analysis/c3s/runs/s3/queries.log
echo >> /Users/jbotts/frus-analysis/c3s/runs/s3/queries.log
sqlite3 -readonly /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "$1"
