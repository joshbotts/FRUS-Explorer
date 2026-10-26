# usage: readdocs.py [--max N] [--ctx REGEX] [--win W] vol/doc [vol/doc ...]
# Retrieves each document whole (header, dateline, source_note, body_text) with an explicit SELECT, saves it under raw/, checks captured length == SQL length(body_text),
# appends to work/reading_ledger.tsv, and prints the document (whole if <= --max characters of body, otherwise opening + windows around --ctx matches).
import sys, re, os, argparse
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
ap = argparse.ArgumentParser()
ap.add_argument("--max", type=int, default=4500); ap.add_argument("--ctx", default=r"recogni\w*|nonrecogni\w*|non-recogni\w*|unrecogni\w*"); ap.add_argument("--win", type=int, default=700)
ap.add_argument("ids", nargs="+")
a = ap.parse_args()
conn = frus.connect()
RAW = frus.RUN + "/raw"
led = open(frus.RUN + "/work/reading_ledger.tsv", "a")
if os.path.getsize(frus.RUN + "/work/reading_ledger.tsv") == 0:
    led.write("volume_id\tdocument_id\tsql_length_chars\tcaptured_chars\tretrieved_whole\tprinted_chars\tprinted_whole\n")
cr = re.compile(a.ctx, re.I)
for tok in a.ids:
    v, d = tok.split("/")
    rows = frus.sql(conn, "SELECT volume_id, document_id, header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id = ? AND document_id = ?", (v, d), script="scripts/readdocs.py")
    if not rows:
        print("!! not found:", tok); continue
    v, d, h, dl, sn, bt, ln = rows[0]
    bt = bt or ""
    base = "%s/%s__%s" % (RAW, v, d)
    open(base + ".body.txt", "w").write(bt)
    open(base + ".meta.txt", "w").write("HEADER: %s\nDATELINE: %s\nSOURCE NOTE: %s\n" % (frus.collapse(h), frus.collapse(dl), frus.collapse(sn)))
    whole = (len(bt) == ln)
    di = frus.sql(conn, "SELECT date_iso FROM document_dates WHERE volume_id = ? AND document_id = ?", (v, d), script="scripts/readdocs.py")
    di = di[0][0] if di else None
    print("=== %s/%s | %s | %s" % (v, d, di, frus.collapse(h)))
    print("    %s | src: %s" % (frus.collapse(dl), frus.collapse(sn)[:120]))
    body = re.sub(r"[ \t]+\n", "\n", bt).strip()
    if len(body) <= a.max:
        out = body; pw = True
    else:
        pieces = [body[:600]]
        last = 600
        for m in cr.finditer(body):
            s0 = max(0, m.start() - a.win // 2)
            if s0 < last: s0 = last
            s1 = min(len(body), m.start() + a.win // 2)
            if s1 <= s0: continue
            pieces.append("\n[...]\n" + body[s0:s1]); last = s1
            if sum(len(p) for p in pieces) > a.max: break
        out = "".join(pieces) + "\n[... truncated for display; full text saved on disk ...]"
        pw = False
    print(out)
    led.write("%s\t%s\t%d\t%d\t%s\t%d\t%s\n" % (v, d, ln, len(bt), "Y" if whole else "N", len(body) if pw else len(out), "Y" if pw else "N"))
    print()
led.close()
