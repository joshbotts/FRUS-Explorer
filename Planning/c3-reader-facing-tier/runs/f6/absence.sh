#!/bin/zsh
DB=/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db
IN=$(cat /Users/jbotts/frus-analysis/c3f/runs/f6/eap_in.txt)
run(){ sqlite3 -readonly $DB "SELECT '$1', COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '$2' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ($IN);"; }
run "POSITIVE Department of State" '"Department of State"'
run "NEGATIVE ZZZ_IMPOSSIBLE_ZZZ" '"ZZZ_IMPOSSIBLE_ZZZ"'
run "survey/poll with USIA/USIS" '(USIA OR USIS) AND (poll OR survey OR "opinion research" OR "research report" OR "audience research")'
run "poll or survey of Asian opinion" '("public opinion" OR poll OR survey) AND (Asian OR Asians) AND (USIA OR USIS OR propaganda)'
run "leaflet/script/film/broadcast text" '(leaflet OR leaflets OR "radio script" OR "film script" OR "VOA script") AND (USIA OR USIS OR "Voice of America")'
run "Peace Corps" '"Peace Corps"'
run "Fulbright program (not Senator)" '(Fulbright AND (grant OR scholar OR exchange OR educational))'
run "binational center" '("binational center" OR "bi-national center" OR "Binational Centers")'
