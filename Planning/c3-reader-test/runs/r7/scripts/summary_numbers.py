# Remaining summary numbers for the memo: channel volume counts, core docs without a source row, the 1907 convention check,
# the 1981-88 control, the pre-1910 came-from series from central-files-index.json countrySeries, and Reagan Library Latin America records.
import sqlite3, json, collections
R="/Users/jbotts/frus-analysis/c3/runs/r7/out/"; B="/Applications/FRUS Explorer.app/Contents/Resources/"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows=[l.rstrip("\n").split("\t") for l in open(R+"core_set.tsv")][1:]
A={(v,d) for v,d,iso,a,b,p in rows if a=="1"}; core={(v,d) for v,d,iso,a,b,p in rows}
print("channel A: docs", len(A), "volumes", len({v for v,d in A}), "| core A|B: docs", len(core), "volumes", len({v for v,d in core}))
con.execute("CREATE TEMP TABLE core(volume_id TEXT, document_id TEXT, PRIMARY KEY(volume_id, document_id))"); con.executemany("INSERT INTO core VALUES (?,?)", list(core))
q="SELECT COUNT(*) FROM core c LEFT JOIN document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE s.volume_id IS NULL"
print("core docs with NO document_sources row:", con.execute(q).fetchone()[0], "| SQL:", q)
q2="SELECT substr(d.date_iso,1,3)||'0s', COUNT(*) FROM core c LEFT JOIN document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE s.volume_id IS NULL GROUP BY 1 ORDER BY 1"
print("  by decade:", con.execute(q2).fetchall())
q3="SELECT COUNT(*) FROM core c JOIN document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id"
print("core docs WITH a document_sources row:", con.execute(q3).fetchone()[0])
for label,m in (("frus1907p2 NEAR(recogn* \"coup d\",30)",'NEAR(recogn* "coup d", 30)'),("frus1907p2 \"additional convention\"",'"additional convention"'),("frus1907p2 Department of State (control)",'"department of state"'),("frus1907p2 ZZZ (control)","ZZZ_IMPOSSIBLE_ZZZ")):
    print(label, con.execute("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH ? AND volume_id='frus1907p2'",(m,)).fetchone()[0])
hits=con.execute("SELECT volume_id, document_id, substr(header,1,80), substr(dateline,1,40) FROM frus_documents WHERE frus_documents MATCH ? AND volume_id='frus1907p2'",('NEAR(recogn* "coup d", 30)',)).fetchall()
print("  frus1907p2 coup/recogn hits:", hits[:6])
cf=json.load(open(B+"central-files-index.json"))
want={"mexico","peru","chile","venezuela","honduras","nicaragua","haiti","costa rica","costa-rica","bolivia"}
print("## pre-1910 came-from series (central-files-index countrySeries: file units for the 19th-century episodes' countries)")
for cs in cf["countrySeries"]:
    if cs["category"] not in ("diplomaticDespatches","diplomaticInstructions","notesFromForeignMissions"): continue
    seen=set()
    for r in cs["rolls"]:
        if any(g in want for g in r.get("geoKeys",[])):
            key=(r.get("fileUnitTitle"), r.get("fileUnitNaId"))
            if key in seen: continue
            seen.add(key)
            if any(k in (r.get("fileUnitTitle") or "") for k in ("Mexico","Peru","Chile","Venezuela","Honduras","Nicaragua","Haiti","Costa Rica","Bolivia","Central America")):
                print(f"  {cs['displayName']}: {r.get('fileUnitTitle')} | file unit NAID {r.get('fileUnitNaId')} | series NAID {r.get('naId')} | {r.get('startISO','')[:4]}-{r.get('endISO','')[:4]} | {r.get('catalogURL')}")
    print("   (roll fields:", sorted(cs["rolls"][0].keys()), ")")
plc=json.load(open(B+"presidential-library-catalog.json"))
for lib in plc["libraries"]:
    if lib["citedAs"]=="Reagan Library":
        for col in lib["collections"]:
            t=col.get("title") or ""
            if "Latin" in t or "Inter-American" in t or "Western Hemisphere" in t:
                print("## Reagan Library:", t, "| identifier", col.get("identifier"), "| NAID", col.get("naId"), "| series", [(s.get("title"), s.get("naId"), s.get("inclusiveDates")) for s in col.get("series",[])][:4])
