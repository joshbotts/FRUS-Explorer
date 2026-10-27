# [JSON] Gloss the top came-from decimal keys with decimal-class-labels.json, schedule 1910-1949 only (the documents
# carrying 837.x/611.37x/737.x keys are checked to fall inside a glossable span by their own date_iso; see output).
import json, sqlite3
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
j = json.load(open(R + "decimal-class-labels.json"))
s = j["schedules"][0]; print("schedule", s["id"], s["startYear"], s["endYear"])
sub = s["subjects"]
print("subjects['8'] type", type(sub["8"]), list(sub["8"].items())[:3] if isinstance(sub["8"], dict) else sub["8"][:3])
for k in ["00", "51", "61351", "156", "6135"]:
    for c in ["8", "6"]:
        v = sub[c].get(k) if isinstance(sub[c], dict) else None
        if v: print(f"class {c} subject {k}: {v}")
print("class 6:", s["classes"]["6"], "| class 7:", s["classes"]["7"], "| country 37:", s["countries"]["37"], "| country 11:", s["countries"]["11"])
print("relationsClasses", json.dumps(s["relationsClasses"])[:300]); print("countryArrangedClasses", s["countryArrangedClasses"])
m = sqlite3.connect(":memory:"); m.execute("ATTACH DATABASE 'file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro' AS f")
for key in ["837.00", "837.51", "837.61351", "611.3731", "737.00"]:
    r = m.execute("SELECT MIN(d.date_iso), MAX(d.date_iso), COUNT(*) FROM f.document_sources s JOIN f.document_dates d ON d.volume_id=s.volume_id AND d.document_id=s.document_id WHERE s.decimal_class=?", (key,)).fetchone()
    print(key, "date span of all came-from rows corpus-wide:", r)
