# Gloss each cited document's decimal file key with decimal-class-labels.json, only when the document's own date falls inside a glossable span (coverage.glossableYears).
import json, re, sys, sqlite3
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
R = "/Applications/FRUS Explorer.app/Contents/Resources"
d = json.load(open(R + "/decimal-class-labels.json"))
scheds = {s["id"]: s for s in d["schedules"]}
spans = d["coverage"]["glossableYears"]
conn = frus.connect()
conn.execute("ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % frus.RUN)
frus.log_line("# gloss_cited.py: next statement is run after ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % frus.RUN)
rows = frus.sql(conn, "SELECT c.finding, c.volume_id, c.document_id, sd.date_iso, ds.citation_era, ds.series_name, ds.decimal_class, ds.repository, ds.record_group FROM s.cited c JOIN s.scope_docs sd ON sd.volume_id=c.volume_id AND sd.document_id=c.document_id LEFT JOIN document_sources ds ON ds.volume_id=c.volume_id AND ds.document_id=c.document_id ORDER BY c.finding, sd.date_iso", script="scripts/gloss_cited.py")
for f, v, did, di, era, sn, lot, repo, rg in rows:
    line = "F%d %s/%s %s | %s | %s %s" % (f, v, did, di, era, repo or "", ("RG " + rg) if rg else "")
    if era == "decimal" and lot:
        m = re.match(r"(\d)(\d\d)([a-z]?)\.?(\S*)", lot)
        yr = int(di[:4]) if di else None
        sched = None
        for sp in spans:
            if yr and sp["startYear"] <= yr <= sp["endYear"]:
                sched = scheds[sp["scheduleId"]]
        if m and sched:
            cl, ctry, _, sub = m.groups()
            sub_gloss = sched["subjects"].get(cl, {}).get(sub) if sub else None
            line += " | key %s -> schedule %s: class %s = %s; country %s = %s%s" % (lot, sched["id"], cl, sched["classes"].get(cl), ctry, sched["countries"].get(ctry), ("; subject %s = %s" % (sub, sub_gloss)) if sub_gloss else "")
        else:
            line += " | key %s -> no gloss (document date %s outside glossable years or malformed)" % (lot, di)
    else:
        line += " | series: %s" % (sn or "")[:80]
    print(line)
