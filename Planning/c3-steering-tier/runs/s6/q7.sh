DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
for t in '"Tongsun Park"' '"Park Tong Sun" OR "Park Tong-sun"' 'Koreagate' 'Watergate' 'BCCI OR "Bank of Credit and Commerce"' '"Teapot Dome"' 'Abscam' '"Iran-Contra"' 'defalcation' '"Credit Mobilier"' 'Church AND Subcommittee AND Multinational' '"Nixon Presidential" ' ; do
 q="SELECT '$t', COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '$(echo "$t" | sed "s/'/''/g")' AND d.is_front_matter=0 AND d.is_editorial_note=0;"
 echo "$q" >> queries.log; sqlite3 "$DB" "$q"
done
