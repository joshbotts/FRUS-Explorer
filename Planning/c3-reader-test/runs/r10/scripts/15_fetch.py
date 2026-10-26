# Retrieve documents whole and keep the raw text on disk (raw/<volume_id>__<document_id>.txt), for reading and quoting.
# argv: volume_id/document_id ... (5 to 15 per call)
# SQL run: SELECT volume_id, document_id, document_number, header, dateline, source_note, body_text, length(body_text),
#          is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?;
import sqlite3, sys
R = "/Users/jbotts/frus-analysis/c3/runs/r10/raw/"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
for arg in sys.argv[1:]:
    v, d = arg.split("/")
    r = con.execute("SELECT volume_id, document_id, document_number, header, dateline, source_note, body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if not r:
        print("NOT FOUND", arg); continue
    with open(R + "%s__%s.txt" % (v, d), "w") as f:
        f.write("HEADER: %s\nDATELINE: %s\nSOURCE_NOTE: %s\nBODY:\n%s\n" % (r[3], r[4], r[5], r[6]))
    print("%s/%s len(body_text)=%d captured=%d front=%d ednote=%d | %s" % (v, d, r[7], len(r[6]), r[8], r[9], " ".join(r[3].split())[:100]))
