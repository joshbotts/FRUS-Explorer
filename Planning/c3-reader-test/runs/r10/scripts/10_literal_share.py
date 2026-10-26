# Literal share of an FTS family's hit list (house rule (a)).
# argv: hits_file  strict_regex  tolerant_regex  [n_sample=40]  [label]
# Sample: evenly spaced n from the (volume_id, document_id)-sorted hit list; the whole list when it is under 300 and
# n_sample is 'census'. Text = header + ' ' + dateline + ' ' + source_note + ' ' + body_text, whitespace-collapsed.
# Matching uses Python re with re.IGNORECASE for BOTH passes (stated in the memo).
# SQL run (5 documents per call): SELECT volume_id, document_id, header, dateline, source_note, body_text
#   FROM document_cache WHERE (volume_id, document_id) IN (VALUES (?,?),...);
import re, sqlite3, sys
hits_file, strict, tolerant = sys.argv[1], sys.argv[2], sys.argv[3]
nsamp = sys.argv[4] if len(sys.argv) > 4 else "40"
hits = []
for line in open(hits_file):
    f = line.rstrip("\n").split("\t")
    hits.append((f[0], f[1]))
hits = sorted(set(hits))
M = len(hits)
if nsamp == "census":
    sample = hits
else:
    n = int(nsamp)
    sample = hits if M <= n else [hits[int(i * M / n)] for i in range(n)]
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rs, rt = re.compile(strict, re.I), re.compile(tolerant, re.I)
ns = nt = 0; misses = []
for i in range(0, len(sample), 5):
    chunk = sample[i:i + 5]
    q = "SELECT volume_id, document_id, header, dateline, source_note, body_text FROM document_cache WHERE (volume_id, document_id) IN (VALUES %s)" % ",".join(["(?,?)"] * len(chunk))
    args = [x for k in chunk for x in k]
    for v, d, h, dl, sn, b in con.execute(q, args):
        t = " ".join(" ".join([h or "", dl or "", sn or "", b or ""]).split())
        s = rs.search(t); tt = rt.search(t)
        ns += 1 if s else 0; nt += 1 if tt else 0
        if not tt:
            # show where the stem appears, for reading the miss
            m = re.search(r"recogni|recognis|nonrecog", t, re.I)
            ctx = t[max(0, m.start() - 120): m.start() + 160] if m else t[:200]
            misses.append((v, d, ctx))
        elif not s:
            misses.append((v, d, "TOLERANT-ONLY: " + t[max(0, tt.start() - 60): tt.end() + 60]))
print("hit list:", hits_file, "M =", M, "sample size =", len(sample))
print("STRICT  %d of %d" % (ns, len(sample)))
print("TOLERANT %d of %d" % (nt, len(sample)))
print("sample ids:", " ".join("%s/%s" % k for k in sample))
for v, d, c in misses:
    print("MISS-or-tolerant-only\t%s/%s\t%s" % (v, d, c))
