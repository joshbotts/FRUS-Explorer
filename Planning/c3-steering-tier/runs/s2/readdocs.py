# read documents whole; save raw text; report captured length vs length(body_text)
import sqlite3, sys, os
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL = ("SELECT c.header, COALESCE(c.dateline,''), COALESCE(c.source_note,''), c.body_text, length(c.body_text), t.date_iso "
       "FROM document_cache c LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id "
       "WHERE c.volume_id=? AND c.document_id=?")
print("SQL:", SQL)
for pair in sys.argv[1:]:
    v, d = pair.split("/")
    r = con.execute(SQL, (v, d)).fetchone()
    if r is None: print(pair, "NOT FOUND"); continue
    path = "texts/%s__%s.txt" % (v, d)
    open(path, "w").write("HEADER: %s\nDATELINE: %s\nSOURCE: %s\nDATE: %s\n\n%s" % (r[0], r[1], r[2], r[5], r[3]))
    print(pair, "captured", len(r[3]), "length(body_text)", r[4], "WHOLE" if len(r[3])==r[4] else "PARTIAL", r[5], "|", r[0][:90])
