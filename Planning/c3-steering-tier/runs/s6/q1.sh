DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
for t in 'corrupt' 'bribe' 'graft' 'kickback' 'embezzle' 'malfeasance' 'venal' 'peculation' 'extortion' 'payoff' '"Department of State"' 'ZZZ_IMPOSSIBLE_ZZZ' '"corrupt practices"' '"Foreign Corrupt Practices"' 'Lockheed' '"illegal payments"' '"questionable payments"' 'misappropriat' 'nepotism' 'cronyism' '"bribery"' 'scandal'; do
 q="SELECT '$t', COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '$(echo "$t" | sed "s/'/''/g")' AND d.is_front_matter=0 AND d.is_editorial_note=0;"
 echo "$q" >> queries.log
 sqlite3 "$DB" "$q"
done
