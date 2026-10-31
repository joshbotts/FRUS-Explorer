import json, re, sqlite3, csv
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con = sqlite3.connect(DB, uri=True)
FINAL = [("frus1950v06","d832"),("frus1950v06","d841"),("frus1961-63v23","d356"),("frus1961-63v23","d358"),("frus1977-80v23","d252"),("frus1958-60v01","d111"),("frus1958-60v01","d135"),("frus1964-68v05","d197"),("frus1964-68v05","d258"),("frus1964-68v05","d395"),("frus1964-68v07","d91"),("frus1969-76v06","d175"),("frus1917-72PubDipv07","d177"),("frus1969-76ve09p2","d122"),("frus1969-76v27","d45"),("frus1969-76ve05p2","d119"),("frus1977-80v18","d206"),("frus1969-76ve11p1","d159"),("frus1969-76ve09p2","d161"),("frus1969-76ve12","d218"),("frus1969-76ve12","d219"),("frus1969-76ve12","d224"),("frus1969-76ve15p2","d292"),("frus1969-76v31","d149"),("frus1977-80v03","d248"),("frus1961-63v22","d244"),("frus1961-63v22","d249"),("frus1943China","d202"),("frus1944v06","d269")]
FTS = "corrupt OR bribe OR briberi OR graft OR embezzl* OR venal OR kickback OR malfeas* OR nepot* OR cronyism OR misappropri*"
base = "c.is_front_matter=0 AND c.is_editorial_note=0"
def hits(match, extra=""):
    return set(con.execute("SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND " + base + extra, (match,)).fetchall())
fam = hits(FTS)
print("family MATCH (scan1.py's query) returns", len(fam), "documents (memo: 3,283 incl. Ed2)")
fam_noed2 = {p for p in fam if p[0] not in ("frus1951-54IranEd2", "frus1969-76ve15p2Ed2")}
print("without Ed2:", len(fam_noed2), "(memo: 3,242)")
cor = hits("corrupt")
lock = hits("lockheed AND (brib* OR bribe OR briberi OR payoff OR commission*)")
print("'corrupt' MATCH:", len(cor), "| lockheed census:", len(lock), "(memo: 44)")
hdr = hits("header:corrupt OR header:brib* OR header:graft")
print("header query:", len(hdr), "documents:", sorted(hdr)[:10])
print()
print("pair | family | corrupt-stem | lockheed | header")
miss = []
for p in FINAL:
    f, c, l, h = p in fam, p in cor, p in lock, p in hdr
    if not (f or c or l or h):
        miss.append(p)
    print(f"{p[0]}/{p[1]} | {f} | {c} | {l} | {h}")
print("cited documents returned by NO logged full-text or heading query:", miss)
# scan1.csv agrees?
rows = {(r["volume_id"], r["document_id"]): r for r in csv.DictReader(open("/Users/jbotts/frus-analysis/c3s/runs/s1/scan1.csv"))}
print("scan1.csv rows:", len(rows), "| all 29 present:", all(p in rows for p in FINAL))
print("d841 in scan1.csv:", rows.get(("frus1950v06", "d841")))
# the printed lists the memo says it read from: the 70 densest, and the 280 with fam>=4
sr = sorted(rows.values(), key=lambda r: -int(r["fam"]))
top70 = {(r["volume_id"], r["document_id"]) for r in sr[:70]}
ge4 = {(r["volume_id"], r["document_id"]) for r in rows.values() if int(r["fam"]) >= 4 and r["volume_id"] not in ("frus1951-54IranEd2", "frus1969-76ve15p2Ed2")}
print("top-70 by fam size:", len(top70), "| fam>=4 (Ed2 removed):", len(ge4), "(memo: 280)")
print("d841 in top70:", ("frus1950v06", "d841") in top70, "| in fam>=4:", ("frus1950v06", "d841") in ge4)
print("cited docs NOT in top70 and NOT in fam>=4 (so not on either printed list):", [p for p in FINAL if p not in top70 and p not in ge4])
print("fam counts of the 29:", {f"{v}/{d}": rows[(v, d)]["fam"] for v, d in FINAL})
