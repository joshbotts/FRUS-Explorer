# False-friend test. For each term, the share of numbered, non-apparatus documents (no Ed2 duplicates) containing it, by stratum:
#   A = hemisphere volumes (whole volume), B = Latin American sections of other volumes, C = everything else.
# A term whose share in A/B is about the share of the controls' (treaty, Department of State) ratio to C is measuring the corpus, not the question.
import sys
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
conn = frus.connect()
conn.execute("ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % frus.RUN)
frus.log_line("# false_friend.py: the statements below are run after ATTACH 'file:%s/work/scope.db?mode=ro' AS s" % frus.RUN)
den = dict(((r[0]), r[1]) for r in frus.sql(conn, "SELECT CASE WHEN sd.lat_basis='hemisphere volume' THEN 'A' WHEN sd.lat_basis='latam section' THEN 'B' ELSE 'C' END AS st, COUNT(*) FROM s.scope_docs sd WHERE sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0 GROUP BY 1", script="scripts/false_friend.py"))
TERMS = [
 ("recogn* (any form)", "recogn*", "question's own term"),
 ("recognition near government/regime/junta/administration (6)", "NEAR(recogn* government*, 6) OR NEAR(recogn* regime*, 6) OR NEAR(recogn* junta, 6) OR NEAR(recogn* administration*, 6)", "question's own term"),
 ("nonrecogn* / non recogn*", "nonrecogn* OR \"non recogn*\"", "editors' term"),
 ("revolut*", "revolut*", "editors' term"),
 ("coup", "coup", "editors' term"),
 ("junta", "junta", "editors' term"),
 ("overthrow*", "overthrow*", "editors' term"),
 ("\"de facto\"", "\"de facto\"", "editors' term"),
 ("\"constitutional government\"", "\"constitutional government\"", "editors' term"),
 ("\"provisional government\"", "\"provisional government\"", "editors' term"),
 ("\"military junta\"", "\"military junta\"", "editors' term"),
 ("CONTROL treati*", "treati*", "control (common word)"),
 ("CONTROL \"department of state\"", "\"department of state\"", "positive control"),
 ("CONTROL ZZZ_IMPOSSIBLE_ZZZ", "ZZZ_IMPOSSIBLE_ZZZ", "negative control"),
]
out = open(frus.RUN + "/work/false_friend.tsv", "w")
out.write("term\tkind\tFTS_expression\tA_docs\tA_of\tB_docs\tB_of\tC_docs\tC_of\tA_share\tB_share\tC_share\tA_over_C\tB_over_C\n")
print("strata sizes (docs): A hemisphere volumes=%d, B latam sections of other volumes=%d, C everything else=%d" % (den["A"], den["B"], den["C"]))
for name, expr, kind in TERMS:
    r = frus.sql(conn, "SELECT CASE WHEN sd.lat_basis='hemisphere volume' THEN 'A' WHEN sd.lat_basis='latam section' THEN 'B' ELSE 'C' END AS st, COUNT(*) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id WHERE frus_documents MATCH ? AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0 GROUP BY 1", (expr,), script="scripts/false_friend.py")
    d = dict(r)
    a, b, c = d.get("A", 0), d.get("B", 0), d.get("C", 0)
    sh = [x / den[k] for x, k in ((a, "A"), (b, "B"), (c, "C"))]
    ra = sh[0] / sh[2] if sh[2] else float("nan"); rb = sh[1] / sh[2] if sh[2] else float("nan")
    out.write("%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%.4f\t%.4f\t%.4f\t%.2f\t%.2f\n" % (name, kind, expr, a, den["A"], b, den["B"], c, den["C"], sh[0], sh[1], sh[2], ra, rb))
    print("%-62s | A %5d of %d (%.1f%%) | B %5d of %d (%.1f%%) | C %6d of %d (%.1f%%) | A/C %.2f B/C %.2f" % (name, a, den["A"], 100 * sh[0], b, den["B"], 100 * sh[1], c, den["C"], 100 * sh[2], ra, rb))
