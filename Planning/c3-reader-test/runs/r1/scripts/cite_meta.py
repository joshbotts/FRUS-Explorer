# Build work/cite_meta.tsv for the cited documents: short printed title (from manifest.json via work/manifest_list.tsv), document number, header, dateline, day, starting printed page.
import csv, re, sys
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
man = {r["volumeId"]: r for r in csv.DictReader(open(frus.RUN + "/work/manifest_list.tsv"), delimiter="\t")}
conn = frus.connect()
conn.execute("ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % frus.RUN)
frus.log_line("# cite_meta.py: next statements run after ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % frus.RUN)
rows = frus.sql(conn, "SELECT c.finding, c.volume_id, c.document_id, c.role, d.document_number, d.header, d.dateline, sd.date_iso FROM s.cited c JOIN document_cache d ON d.volume_id=c.volume_id AND d.document_id=c.document_id JOIN s.scope_docs sd ON sd.volume_id=c.volume_id AND sd.document_id=c.document_id ORDER BY c.finding, sd.date_iso, c.volume_id, c.document_id", script="scripts/cite_meta.py")
def short_title(vid):
    t = man[vid]["title"]
    if "With the Annual Message" in t or "With the Address of the President" in t:
        yr = man[vid]["subseries"]
        t = "Papers Relating to the Foreign Relations of the United States, %s" % yr
    return t
out = open(frus.RUN + "/work/cite_meta.tsv", "w")
out.write("finding\tvolume_id\tdocument_id\trole\tdocument_number\tdate_iso\tpage\tshort_title\theader\tdateline\n")
for f, v, d, role, num, h, dl, di in rows:
    pg = frus.sql(conn, "SELECT page_number_raw FROM page_ranges WHERE volume_id = ? AND document_id = ? AND is_start = 1", (v, d), script="scripts/cite_meta.py", log=False)
    out.write("\t".join([str(f), v, d, role, str(num), str(di), pg[0][0] if pg else "", short_title(v), frus.collapse(h), frus.collapse(dl)]) + "\n")
out.close()
print(len(rows), "rows")
