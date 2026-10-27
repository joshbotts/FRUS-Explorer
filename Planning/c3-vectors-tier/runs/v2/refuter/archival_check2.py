import json, sqlite3
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
cf = json.load(open(R + "central-files-index.json"))
print("== nineteenth-century file units (countrySeries rolls with geoKeys cuba/spain)")
seen = {}
for cat in cf["countrySeries"]:
    for roll in cat["rolls"]:
        if any(g in ("cuba", "spain") for g in roll.get("geoKeys", [])):
            k = (cat["displayName"], roll.get("fileUnitTitle"), str(roll.get("fileUnitNaId")))
            a = seen.setdefault(k, [0, set()]); a[0] += 1
            for x in (roll.get("startISO"), roll.get("endISO")):
                if x: a[1].add(x[:4])
for k, v in seen.items(): print("  ", k, "rolls", v[0], "years", (min(v[1]), max(v[1])) if v[1] else None)
for want in ("177380726", "177380758", "183303928"):
    print("  claimed file unit", want, "present:", [k for k in seen if k[2] == want])
print("\n== decimal classes (decimal-class-labels.json)")
j = json.load(open(R + "decimal-class-labels.json"))
print("coverage:", json.dumps(j.get("coverage"))[:600])
for s in j["schedules"]:
    print("schedule", s.get("id"), s.get("startYear"), s.get("endYear"), "| class 8:", s["classes"].get("8"), "| class 6:", s["classes"].get("6"), "| class 7:", s["classes"].get("7"), "| country 37:", s["countries"].get("37"), "| country 11:", s["countries"].get("11"))
    sub = s.get("subjects") or {}
    for c, k in [("8", "00"), ("8", "51"), ("8", "61351"), ("6", "37"), ("6", "3731")]:
        print("   subject", c, k, "->", (sub.get(c) or {}).get(k) if isinstance(sub.get(c), dict) else None)
print("\n== document_sources rows over the core set for the named repositories/classes")
m = sqlite3.connect(":memory:"); m.execute("ATTACH DATABASE 'file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro' AS f")
m.execute("CREATE TEMP TABLE core(volume_id TEXT, document_id TEXT)")
m.executemany("INSERT INTO core VALUES (?,?)", [tuple(p.split("/")) for p in json.load(open("my_core_pairs.json"))])
for rep in ["Kennedy Library", "Johnson Library", "Nixon Presidential Materials", "Carter Library", "Central Intelligence Agency"]:
    print("  ", rep, m.execute("SELECT COUNT(*), GROUP_CONCAT(DISTINCT s.series_name) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE s.repository=?", (rep,)).fetchone())
for lot in ["65D438","74D272","66D501","62D24","62D418","62D1","66D95","66D204","65D212"]:
    cf_ = m.execute("SELECT COUNT(*) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE s.lot_file_norm=?", (lot,)).fetchone()[0]
    pa = m.execute("SELECT COUNT(DISTINCT e.volume_id||'/'||e.document_id) FROM core c JOIN f.external_citations e ON e.volume_id=c.volume_id AND e.document_id=c.document_id WHERE e.lot_file_norm=?", (lot,)).fetchone()[0]
    print("   lot", lot, "came-from rows", cf_, "pointed-at docs", pa)
for dc in ["837.00", "837.51", "837.61351", "611.37", "611.3731"]:
    print("   decimal_class", dc, "came-from over core:", m.execute("SELECT COUNT(*) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE s.decimal_class=?", (dc,)).fetchone()[0], "| corpus-wide date span:", m.execute("SELECT MIN(d.date_iso), MAX(d.date_iso) FROM f.document_sources s JOIN f.document_dates d ON d.volume_id=s.volume_id AND d.document_id=s.document_id WHERE s.decimal_class=?", (dc,)).fetchone())
print("   record_group values among core came-from rows:", m.execute("SELECT s.record_group, COUNT(*) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id GROUP BY 1 ORDER BY 2 DESC LIMIT 6").fetchall())
print("   came-from rows dated before 1950 by repository/record_group:", m.execute("SELECT s.repository, s.record_group, s.citation_era, COUNT(*) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id JOIN f.document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE d.date_iso < '1950' GROUP BY 1,2,3 ORDER BY 4 DESC LIMIT 8").fetchall())
print("   came-from rows dated after 1958 by repository:", m.execute("SELECT s.repository, COUNT(*) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id JOIN f.document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE d.date_iso >= '1959' GROUP BY 1 ORDER BY 2 DESC LIMIT 8").fetchall())
