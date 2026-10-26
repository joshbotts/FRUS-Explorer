# Census check of the documents that refer to the cited-but-unprinted statements (house rule (a), census for a family
# argued from): for each document print the literal contexts. Text = header+dateline+source_note+body_text,
# whitespace-collapsed; Python re, case-sensitive.
# SQL (lists from the FTS queries logged above): SELECT header, dateline, source_note, body_text FROM document_cache
#   WHERE volume_id=? AND document_id=?;
import re, sqlite3
SETS = {
 "Acheson 19 Sept 1949": (["frus1949v02/d339","frus1949v02/d374","frus1949v02/d444","frus1949v02/d446","frus1949v02/d448","frus1949v02/d467","frus1950v02/d22","frus1950v02/d191","frus1950v02/d300","frus1950v02/d329","frus1950v02/d334","frus1951v02/d158"],
                          r"September 19,? 1949|September 19\b"),
 "Mann Notre Dame 1964": (["frus1964-68v31/d17"], r"Notre Dame"),
 "Senate Resolution 205": (["frus1969-76ve10/d14","frus1969-76ve16/d148","frus1977-80v22/d43"], r"Resolution \(?205\)?|Cranston Resolution"),
}
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
for name, (ids, pat) in SETS.items():
    rx = re.compile(pat); n = 0
    print("==", name, "documents:", len(ids))
    for k in ids:
        v, d = k.split("/")
        h, dl, sn, b = con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
        t = " ".join(" ".join([h or "", dl or "", sn or "", b or ""]).split())
        m = rx.search(t)
        if m: n += 1
        print("  %s %s | %s" % (k, "MATCH" if m else "no-literal", (t[max(0, m.start() - 150): m.end() + 150] if m else "")))
    print("  literal share: %d of %d" % (n, len(ids)))
