# usage: share_test.py NAME 'FTS EXPR' FAMILY [--from D] [--to D] [--latam 1]
# Literal-share test for a phrase count. Hit list = scope documents (numbered, non-apparatus, no Ed2) matching the FTS expression, sorted by (volume_id, document_id) as text.
# Whole set if under 300 hits, otherwise an evenly spaced sample of 40: indices round(i*(n-1)/39). Each tested document's text is header+dateline+source_note+body_text, whitespace-collapsed.
# STRICT = single spaces between the words; TOLERANT = inflections and any run of space, hyphen, comma, parenthesis or full stop between the words. Case-insensitive (re.I) for both.
import sys, re, argparse
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
FAM = {
 "C": (  # recognition within six words of government / regime / junta / administration, either order
   r"\b(?:recognition|recognitions|recognize|recognizes|recognized|recognizing)(?: [A-Za-z]+){0,6}? (?:government|governments|regime|regimes|junta|juntas|administration|administrations)\b"
   r"|\b(?:government|governments|regime|regimes|junta|juntas|administration|administrations)(?: [A-Za-z]+){0,6}? (?:recognition|recognitions|recognize|recognizes|recognized|recognizing)\b",
   r"\b(?:non-?|un)?recogni(?:tion\w*|[sz]\w*)(?:[\s\-,.()]+\w+){0,6}?[\s\-,.()]+(?:government|regime|junta|administration)\w*"
   r"|\b(?:government|regime|junta|administration)\w*(?:[\s\-,.()]+\w+){0,6}?[\s\-,.()]+(?:non-?|un)?recogni(?:tion\w*|[sz]\w*)"),
 "W": (  # non-recognition and withholding / refusing / declining / deferring recognition
   r"\b(?:nonrecognition|non-recognition|non recognition|unrecognized)\b"
   r"|\b(?:withhold|withholds|withholding|withheld|refuse|refuses|refused|refusing|refusal|decline|declines|declined|declining|deny|denies|denied|denying|postpone|postponed|postponing|defer|deferred|deferring)(?: [A-Za-z]+){0,5}? (?:recognition|recognize|recognized|recognizing)\b",
   r"\b(?:non[\s\-]?|un)recogni(?:tion\w*|[sz]\w*)"
   r"|\b(?:withh\w+|refus\w+|declin\w+|den(?:y|ied|ies|ying)|postpon\w+|defer\w*)(?:[\s\-,.()]+\w+){0,5}?[\s\-,.()]+recogni(?:tion\w*|[sz]\w*)"),
}
ap = argparse.ArgumentParser()
ap.add_argument("name"); ap.add_argument("expr"); ap.add_argument("family"); ap.add_argument("--strict-rx", default=None); ap.add_argument("--tol-rx", default=None)
ap.add_argument("--from", dest="dfrom", default=None); ap.add_argument("--to", dest="dto", default=None); ap.add_argument("--latam", type=int, default=1)
a = ap.parse_args()
strict = re.compile(a.strict_rx if a.family == "X" else FAM[a.family][0], re.I); tol = re.compile(a.tol_rx if a.family == "X" else FAM[a.family][1], re.I)
conn = frus.connect()
conn.execute("ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % frus.RUN)
frus.log_line("# share_test.py %s: the statement below is run after ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % (a.name, frus.RUN))
q = ("SELECT f.volume_id, f.document_id, sd.date_iso FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id "
     "WHERE frus_documents MATCH ? AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0")
p = [a.expr]
if a.latam: q += " AND sd.latam=1"
if a.dfrom: q += " AND sd.date_iso >= ?"; p.append(a.dfrom)
if a.dto: q += " AND sd.date_iso <= ?"; p.append(a.dto)
q += " ORDER BY f.volume_id, f.document_id"
hits = frus.sql(conn, q, tuple(p), script="scripts/share_test.py " + a.name)
n = len(hits)
if n < 300:
    idx = list(range(n)); mode = "whole set (under 300)"
else:
    k = 40; idx = sorted(set(int(round(i * (n - 1) / (k - 1))) for i in range(k))); mode = "evenly spaced sample of %d" % len(idx)
out = open("%s/work/shares/%s.tsv" % (frus.RUN, a.name), "w")
out.write("volume_id\tdocument_id\tdate_iso\tstrict\ttolerant\tsnippet\n")
ks = kt = 0
for i in idx:
    v, d, di = hits[i]
    r = frus.sql(conn, "SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id = ? AND document_id = ?", (v, d), script="scripts/share_test.py " + a.name, log=(i == idx[0]))
    h, dl, sn, bt = r[0]
    t = frus.collapse(" ".join([h or "", dl or "", sn or "", bt or ""]))
    ms = strict.search(t); mt = tol.search(t)
    ks += 1 if ms else 0; kt += 1 if mt else 0
    m = mt or ms
    sn_ = t[max(0, m.start() - 110): m.end() + 110] if m else t[:200]
    out.write("%s\t%s\t%s\t%d\t%d\t%s\n" % (v, d, di, 1 if ms else 0, 1 if mt else 0, sn_))
out.close()
print("## %s | MATCH %s | scope=%s | %s..%s" % (a.name, a.expr, "latam" if a.latam else "whole index", a.dfrom or "", a.dto or ""))
print("hit list N=%d (sorted by volume_id, document_id); tested %d (%s)" % (n, len(idx), mode))
print("STRICT   : %d of %d" % (ks, len(idx)))
print("TOLERANT : %d of %d" % (kt, len(idx)))
