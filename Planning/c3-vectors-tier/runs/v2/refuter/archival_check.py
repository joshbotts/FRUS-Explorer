# Confirm every archival identifier in the bottom line's second paragraph against the bundled artifacts and the index.
import json, sqlite3
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
cf = json.load(open(R + "central-files-index.json")); sf = json.load(open(R + "series-facts-index.json"))
print("lotFiles keys:", sorted(cf["lotFiles"][0].keys()))
print("series-facts legend:", json.dumps(sf["legend"])[:900])
print("statuses:", sf["statuses"])
idx = {r["lotNumber"]: r for r in cf["lotFiles"]}
claims = {  # as the overview's second paragraph states them: (title, entry, NAID, y0, y1, access)
 "65D438": ("Records Relating to the Cuban Missile Crisis", "A1 3053", "27022950", 1962, 1963, "partly restricted"),
 "74D272": ("Records of Under Secretary George W. Ball", "A1 5175", "614703", 1961, 1966, "unrestricted"),
 "66D501": ("Files Pertaining to Operation Mongoose", "UD-UP 293-B", "648748", 1963, 1965, "unrestricted"),
 "62D24":  ("Subject Files (Inter-American bureau)", "A1 3148", "2363836", 1958, 1961, "partly restricted"),
 "62D418": ("Subject Files (Inter-American bureau)", "A1 3147", "2068466", 1959, 1962, "partly restricted"),
 "62D1":   ("Policy Planning Council's NSC records", "A1 1583E/F", "2838992", 1948, 1961, "partly restricted"),
 "66D95":  ("Records Relating to NSC Policy Papers", "A1 1586E", "2839192", 1947, 1979, "partly restricted"),
 "66D204": ("Presidential and Secretary of State Correspondence with Foreign Heads of State", "A1 1590", "2538452", 1953, 1964, "possibly restricted"),
 "65D212": ("Records Relating to Sugar", "UD-UP 215", "27022874", 1955, 1962, "fully restricted"),
}
for lot, cl in claims.items():
    r = idx.get(lot)
    print(f"\n== lot {lot} claimed: {cl}")
    if not r: print("   NOT IN central-files-index lotFiles"); continue
    print("   lotFiles row:", json.dumps({k: r[k] for k in r if k not in ('description',)}, ensure_ascii=False)[:700])
    na = str(r.get("naId") or r.get("seriesNaId") or "")
    f = sf["byNaId"].get(na)
    print("   series-facts byNaId[%s]:" % na, f)
    if f:
        for k, v in f.items():
            if k == "c" and isinstance(v, int): print("     creator heading:", sf["headings"][v])
            if k == "as" and isinstance(v, int): print("     access status:", sf["statuses"][v])
print("\n== nineteenth-century file units (countrySeries rolls with geoKeys cuba/spain)")
seen = {}
for cat in cf["countrySeries"]:
    for roll in cat["rolls"]:
        if any(g in ("cuba", "spain") for g in roll.get("geoKeys", [])):
            k = (cat["displayName"], roll.get("fileUnitTitle"), str(roll.get("fileUnitNaId")))
            a = seen.setdefault(k, [0, roll.get("startISO"), roll.get("endISO")]); a[0] += 1
            a[1] = min(a[1], roll.get("startISO")); a[2] = max(a[2], roll.get("endISO"))
for k, v in seen.items(): print("  ", k, v)
for want in ("177380726", "177380758", "183303928"):
    print("  claimed file unit", want, "present:", any(k[2] == want for k in seen))
print("\n== decimal classes (decimal-class-labels.json)")
j = json.load(open(R + "decimal-class-labels.json"))
for s in j["schedules"]:
    print("schedule", s.get("id"), s.get("startYear"), s.get("endYear"), "| class 8:", s["classes"].get("8"), "| class 6:", s["classes"].get("6"), "| country 37:", s["countries"].get("37"), "| country 11:", s["countries"].get("11"))
    sub = s.get("subjects") or {}
    for c, k in [("8", "00"), ("8", "51"), ("8", "61351"), ("6", "37"), ("6", "3731")]:
        print("   subject", c, k, "->", (sub.get(c) or {}).get(k) if isinstance(sub.get(c), dict) else None)
print("\n== document_sources rows over the core set for the named repositories/classes")
m = sqlite3.connect(":memory:"); m.execute("ATTACH DATABASE 'file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro' AS f")
m.execute("CREATE TEMP TABLE core(volume_id TEXT, document_id TEXT)")
m.executemany("INSERT INTO core VALUES (?,?)", [tuple(p.split("/")) for p in json.load(open("my_core_pairs.json"))])
for rep in ["Kennedy Library", "Johnson Library", "Nixon Presidential Materials", "Carter Library", "Central Intelligence Agency"]:
    print("  ", rep, m.execute("SELECT COUNT(*), MIN(s.series_name), MAX(s.series_name) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE s.repository=?", (rep,)).fetchone())
for lot in claims:
    cf_ = m.execute("SELECT COUNT(*) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE s.lot_file_norm=?", (lot,)).fetchone()[0]
    pa = m.execute("SELECT COUNT(DISTINCT e.volume_id||'/'||e.document_id) FROM core c JOIN f.external_citations e ON e.volume_id=c.volume_id AND e.document_id=c.document_id WHERE e.lot_file_norm=?", (lot,)).fetchone()[0]
    print("   lot", lot, "came-from rows", cf_, "pointed-at docs", pa)
for dc in ["837.00", "837.51", "837.61351", "611.37", "611.3731"]:
    print("   decimal_class", dc, "came-from over core:", m.execute("SELECT COUNT(*) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE s.decimal_class=?", (dc,)).fetchone()[0], "| corpus-wide date span:", m.execute("SELECT MIN(d.date_iso), MAX(d.date_iso) FROM f.document_sources s JOIN f.document_dates d ON d.volume_id=s.volume_id AND d.document_id=s.document_id WHERE s.decimal_class=?", (dc,)).fetchone())
print("   record_group values among core came-from rows:", m.execute("SELECT s.record_group, COUNT(*) FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id GROUP BY 1 ORDER BY 2 DESC LIMIT 6").fetchall())
