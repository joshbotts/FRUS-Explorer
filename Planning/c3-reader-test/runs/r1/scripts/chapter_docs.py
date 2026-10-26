# usage: chapter_docs.py VOLUME 'PATH REGEX' [--rx 'COUNT REGEX'] [--min N]
# Lists the numbered, non-apparatus documents under section paths of VOLUME matching PATH REGEX: id, date, length, number of matches of COUNT REGEX, header.
import sys, re, argparse
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
ap = argparse.ArgumentParser()
ap.add_argument("vol"); ap.add_argument("pathrx")
ap.add_argument("--rx", default=r"recogni\w*|nonrecogni\w*|non-recogni\w*|unrecogni\w*")
ap.add_argument("--min", type=int, default=0)
a = ap.parse_args()
conn = frus.connect()
conn.execute("ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % frus.RUN)
frus.log_line("# chapter_docs.py: next statement run after ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % frus.RUN)
rows = frus.sql(conn, "SELECT c.document_id, sd.date_iso, sd.section_path, c.header, c.dateline, c.source_note, c.body_text FROM document_cache c JOIN s.scope_docs sd ON sd.volume_id=c.volume_id AND sd.document_id=c.document_id WHERE c.volume_id=? AND sd.numbered=1 AND sd.apparatus=0 ORDER BY sd.date_iso, c.rowid", (a.vol,), script="scripts/chapter_docs.py")
pr = re.compile(a.pathrx, re.I); cr = re.compile(a.rx, re.I)
n = 0
for d, di, sp, h, dl, sn, bt in rows:
    if not pr.search(sp or ""):
        continue
    txt = frus.collapse(" ".join([h or "", dl or "", sn or "", bt or ""]))
    k = len(cr.findall(txt))
    if k < a.min:
        continue
    n += 1
    print("%s/%s | %s | len %d | hits %d | %s | %s" % (a.vol, d, di, len(bt or ""), k, frus.collapse(h)[:70], frus.collapse(dl)[:50]))
print("-- %d documents listed" % n)
