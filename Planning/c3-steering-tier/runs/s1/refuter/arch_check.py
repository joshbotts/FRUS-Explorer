import json, re, sqlite3
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con = sqlite3.connect(DB, uri=True)
pairs = json.load(open("/Users/jbotts/frus-analysis/c3s/runs/s1/refuter/cited_pairs.json")) if False else None
FINAL = [("frus1950v06","d832"),("frus1950v06","d841"),("frus1961-63v23","d356"),("frus1961-63v23","d358"),("frus1977-80v23","d252"),("frus1958-60v01","d111"),("frus1958-60v01","d135"),("frus1964-68v05","d197"),("frus1964-68v05","d258"),("frus1964-68v05","d395"),("frus1964-68v07","d91"),("frus1969-76v06","d175"),("frus1917-72PubDipv07","d177"),("frus1969-76ve09p2","d122"),("frus1969-76v27","d45"),("frus1969-76ve05p2","d119"),("frus1977-80v18","d206"),("frus1969-76ve11p1","d159"),("frus1969-76ve09p2","d161"),("frus1969-76ve12","d218"),("frus1969-76ve12","d219"),("frus1969-76ve12","d224"),("frus1969-76ve15p2","d292"),("frus1969-76v31","d149"),("frus1977-80v03","d248"),("frus1961-63v22","d244"),("frus1961-63v22","d249"),("frus1943China","d202"),("frus1944v06","d269")]

print("== document_sources rows for the 29 cited documents (CAME-FROM) ==")
for v, d in FINAL:
    r = con.execute("SELECT repository, record_group, lot_file, lot_file_norm, series_name, citation_era, decimal_class, substr(raw_text,1,170) FROM document_sources WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    print(f"{v}/{d}", "|", r)

print("\n== source_note text of the 29 (first 220 chars) ==")
for v, d in FINAL:
    r = con.execute("SELECT substr(source_note,1,220) FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    print(f"{v}/{d}", "|", (r[0] or "").replace("\n", " "))

print("\n== external_citations on frus1958-60v01/d135 (lot 62 D 26 claim) ==")
for r in con.execute("SELECT note_ordinal, anchor, repository, collection, lot_file, lot_file_norm, decimal_class, substr(raw_text,1,160) FROM external_citations WHERE volume_id='frus1958-60v01' AND document_id='d135'"):
    print(r)

print("\n== external_citations rows naming lots 62D26, 65F115, 71D461, 76D169 anywhere in the 20 cited volumes (+E-12/E-15 pt 2) ==")
vols = sorted({v for v, _ in FINAL})
q = "SELECT volume_id, document_id, lot_file_norm, substr(raw_text,1,140) FROM external_citations WHERE anchor='lotFile' AND lot_file_norm IN ('62D26','65F115','71D461','76D169') AND volume_id IN (%s) ORDER BY lot_file_norm, volume_id, document_id" % ",".join("'%s'" % v for v in vols)
for r in con.execute(q):
    print(r)
print("65F115 Can Lao folder rows (any volume):")
for r in con.execute("SELECT volume_id, document_id, substr(raw_text,1,160) FROM external_citations WHERE lot_file_norm='65F115' AND raw_text LIKE '%Can Lao%'"):
    print(r)

print("\n== counts the memo's M5.4 states (2,433 rows on 1,472 documents over 18 volumes) ==")
V18 = ['frus1950v06','frus1961-63v23','frus1977-80v23','frus1958-60v01','frus1964-68v05','frus1964-68v07','frus1969-76v06','frus1917-72PubDipv07','frus1969-76ve09p2','frus1969-76v27','frus1969-76ve05p2','frus1977-80v18','frus1969-76ve11p1','frus1969-76v31','frus1977-80v03','frus1961-63v22','frus1943China','frus1944v06']
print(con.execute("SELECT COUNT(*), COUNT(DISTINCT volume_id||'/'||document_id) FROM external_citations WHERE volume_id IN (%s)" % ",".join("'%s'" % v for v in V18)).fetchone())
print("earliest external_citations document date:", con.execute("SELECT MIN(t.date_iso) FROM external_citations e JOIN document_dates t ON t.volume_id=e.volume_id AND t.document_id=e.document_id").fetchone())

# bundle artifacts
def load(name):
    return json.load(open(RES + "/" + name))

print("\n== presidential-library-catalog.json ==")
plc = load("presidential-library-catalog.json")
print("top keys:", list(plc.keys())[:12] if isinstance(plc, dict) else type(plc))
txt = json.dumps(plc)
for naid in ("567979", "165203"):
    for mm in re.finditer(r'"naId"\s*:\s*"?%s"?' % naid, txt):
        print(naid, "->", txt[max(0, mm.start()-400):mm.end()+300].replace("\n", " "))
        break
    else:
        print(naid, "NOT FOUND as naId; raw occurrences:", txt.count(naid))

print("\n== collection-authority.json: lot 79F80 ==")
ca = load("collection-authority.json")
cat = json.dumps(ca)
i = cat.find("79F80")
print("occurrences of 79F80:", cat.count("79F80"))
print(cat[max(0, i-200):i+900] if i >= 0 else "NOT FOUND")

print("\n== central-files-index.json: lotFiles for 62D26 71D461 76D169 65F115 79F80 ==")
cfi = load("central-files-index.json")
print("top keys:", list(cfi.keys())[:12])
lf = cfi.get("lotFiles") or cfi.get("lots") or {}
print("lotFiles type:", type(lf), "n:", len(lf))
for lot in ("62D26", "71D461", "76D169", "65F115", "79F80"):
    if isinstance(lf, dict):
        print(lot, "->", json.dumps(lf.get(lot))[:500])
    else:
        hits = [x for x in lf if lot in json.dumps(x)]
        print(lot, "->", json.dumps(hits[:1])[:500])

print("\n== series-facts-index.json ==")
sf = load("series-facts-index.json")
print("top keys:", list(sf.keys())[:12])
by = sf.get("byNaId") or {}
print("byNaId rows:", len(by))
for naid in ("1965953", "603208", "2602428", "567979", "165203"):
    print(naid, "->", json.dumps(by.get(naid))[:400])
def y0(row):
    ys = [row.get(k) for k in ("y0", "cy0") if isinstance(row.get(k), int)]
    return min(ys) if ys else None
pre = [k for k, r in by.items() if y0(r) is not None and y0(r) < 1940]
print("rows with min(y0,cy0) < 1940:", len(pre), "of", len(by), "=> 1 in %.1f" % (len(by) / max(1, len(pre))))
rgs = {}
for k, r in by.items():
    rg = r.get("rg") or r.get("recordGroup") or r.get("g")
    rgs[rg] = rgs.get(rg, 0) + 1
print("record groups in series-facts:", rgs)

print("\n== volume-sources-index.json / external-citation-index.json: quick presence of the named lots ==")
for name in ("volume-sources-index.json", "external-citation-index.json"):
    try:
        t = json.dumps(load(name))
        print(name, {lot: t.count(lot) for lot in ("79F80", "62D26", "65F115", "71D461", "76D169", "567979", "165203", "1965953", "603208", "2602428")})
    except Exception as e:
        print(name, "ERR", e)
