# scoping pass: family hits by decade (per 1,000 dated non-apparatus docs), controls per volume
import sqlite3, collections, json
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
ED2 = ("frus1951-54IranEd2","frus1969-76ve15p2Ed2")
BASE = ("SELECT c.volume_id, c.document_id, substr(t.date_iso,1,3) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid "
        "LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id "
        "WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN (?,?)")
print("SQL:", BASE)
den = collections.Counter(r[0] for r in con.execute(
    "SELECT substr(t.date_iso,1,3) FROM document_cache c JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id "
    "WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN (?,?) AND t.date_iso IS NOT NULL", ED2))
out = {}
for label, m in [("family","corrupt OR bribe OR briberi OR graft OR kickback OR embezzl"),
                 ("corrupt","corrupt"),("bribe","bribe OR briberi"),("graft","graft"),("embezzl","embezzl"),("kickback","kickback"),
                 ("POS_department_of_state",'"department of state"'),("NEG","ZZZ_IMPOSSIBLE_ZZZ")]:
    rows = con.execute(BASE, (m,)+ED2).fetchall()
    dec = collections.Counter(r[2] for r in rows)
    vols = collections.Counter(r[0] for r in rows)
    out[label] = {"match": m, "n": len(rows), "volumes": len(vols)}
    print(label, m, "docs", len(rows), "volumes", len(vols))
    if label in ("family","corrupt","bribe"):
        for d in sorted(k for k in dec if k):
            # top volume share within decade
            vd = collections.Counter(r[0] for r in rows if r[2]==d)
            tv, tc = vd.most_common(1)[0]
            print("  %s0s %5d of %6d = %.2f per 1000; top volume %s %d of %d" % (d, dec[d], den[d], 1000*dec[d]/den[d], tv, tc, dec[d]))
        print("  undated", dec[None])
    if label == "family":
        json.dump(sorted([list(r[:2]) for r in rows]), open("family_hits.json","w"))
        print("  top volumes:", vols.most_common(25))
    if label == "POS_department_of_state":
        allv = {r[0] for r in con.execute("SELECT DISTINCT volume_id FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN (?,?)", ED2)}
        print("  volumes with zero:", sorted(allv - set(vols)), "of", len(allv))
