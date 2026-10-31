# Refuter: confirm every archival identifier named in the bottom line's second paragraph against the
# bundled artifacts and the index's document_sources / external_citations rows.
import json, re, sqlite3
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
def J(name): return json.load(open(f"{RES}/{name}"))

def src(v, d):
    return con.execute("SELECT repository, record_group, lot_file, lot_file_norm, series_name, citation_era, decimal_class, job_number_norm, raw_text FROM document_sources WHERE volume_id=? AND document_id=?", (v, d)).fetchall()
def cites(v, d):
    return con.execute("SELECT note_ordinal, anchor, repository, collection, lot_file, lot_file_norm, decimal_class, raw_text FROM external_citations WHERE volume_id=? AND document_id=?", (v, d)).fetchall()

print("=== document_sources rows of the cited documents (CAME-FROM) ===")
for v, d in [("frus1944v06","d148"),("frus1947v07","d908"),("frus1948v07","d43"),("frus1958-60v01","d131"),("frus1958-60v01","d135"),("frus1958-60v12","d168"),
             ("frus1946v10","d373"),("frus1955-57v13","d16"),("frus1969-76ve09p2","d152"),("frus1969-76ve15p2","d293"),("frus1964-68v05","d395"),
             ("frus1961-63v22","d202"),("frus1961-63v22","d204"),("frus1969-76ve09p2","d161"),("frus1969-76ve12","d218"),("frus1969-76ve12","d219"),
             ("frus1977-80v03","d248"),("frus1977-80v03","d308"),("frus1964-68v22","d79")]:
    for r in src(v, d): print(f"{v}/{d}: {r[:8]} | {r[8][:200]}")

print("\n=== external_citations rows (POINTED-AT) ===")
for v, d in [("frus1958-60v01","d131"),("frus1958-60v01","d135"),("frus1958-60v12","d168"),("frus1961-63v22","d204"),("frus1969-76ve09p2","d161"),("frus1977-80v03","d248")]:
    for r in cites(v, d): print(f"{v}/{d}: {r}")

print("\n=== d161 body_text: the Jidda embassy file footnote ===")
b = con.execute("SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve09p2' AND document_id='d161'").fetchone()[0]
for m in re.finditer(r".{0,160}(79\s?F\s?80|Jidda Embassy|RG 84|Northrop and Lockheed).{0,160}", b):
    print("   …" + m.group(0).replace("\n", " ") + "…")
print("\n=== d131 body_text: the Saigon embassy file footnote (is RG 84 stated?) ===")
b = con.execute("SELECT body_text FROM document_cache WHERE volume_id='frus1958-60v01' AND document_id='d131'").fetchone()[0]
for m in re.finditer(r".{0,160}(65 F 115|Saigon Embassy Files|RG 84|Record Group 84).{0,160}", b):
    print("   …" + m.group(0).replace("\n", " ") + "…")
print("   'RG 84' anywhere in d131:", "RG 84" in b or "Record Group 84" in b)

print("\n=== curated-lot-resolutions.json ===")
cur = J("curated-lot-resolutions.json")
for l in cur["lots"]:
    if l.get("lotNumber") in ("54D270", "62D181", "62D26", "65F115", "79F80"):
        print(json.dumps(l)[:900])
print("curated series conferenceFiles:", json.dumps(cur["series"].get("conferenceFiles") if isinstance(cur["series"], dict) else [s for s in cur["series"] if "onference" in json.dumps(s)])[:600])

print("\n=== series-facts-index.json rows ===")
sf = J("series-facts-index.json")
legend = sf.get("legend", {})
def decode(naid):
    r = sf["byNaId"].get(str(naid))
    if r is None: return None
    out = {}
    for k, v in r.items():
        spec = legend.get("keys", {}).get(k)
        if spec is None: out[k] = v; continue
        kind, into = spec.get("kind"), spec.get("into")
        if kind == "index": out[spec["field"]] = sf[into][v]
        elif kind == "indexList": out[spec["field"]] = [sf[into][i] for i in v]
        else: out[spec["field"]] = v
    return out
for naid in ("602875", "1965953", "302021", "10481258", "872088", "872091"):
    print(naid, decode(naid))
print("series-facts rows:", len(sf["byNaId"]))

print("\n=== central-files-index.json ===")
cf = J("central-files-index.json")
print("top keys:", list(cf.keys()))
for k in cf:
    if isinstance(cf[k], dict): print("  ", k, "keys:", list(cf[k].keys())[:12])
lots = cf.get("lotFiles", [])
print("lotFiles count:", len(lots))
for l in lots:
    if l.get("lotNumber") in ("62D26", "65F115", "79F80", "54D270", "62D181"): print("  ", l)
# a decimal-file series identifier?
dec = json.dumps({k: v for k, v in cf.items() if k not in ("lotFiles", "countrySeries", "numericalFile")})[:1500]
print("other sections:", dec)
# search for the NAID 302021 anywhere in the bundle
for name in ("central-files-index.json", "collection-authority.json", "series-facts-index.json", "accession-series-index.json", "source-provenance-index.json", "volume-sources-index.json"):
    t = open(f"{RES}/{name}").read()
    print(f"  {name}: '302021' present={('302021' in t)}; 'Central Decimal' present={('Central Decimal' in t)}; '65F115' present={('65F115' in t or '65 F 115' in t)}; '79F80' present={('79F80' in t or '79 F 80' in t)}; '78D433' present={('78D433' in t)}; '5177' present={('5177' in t)}; '5403' present={('5403' in t)}")

print("\n=== collection-authority.json: lots 65F115, 79F80, 62D26, 54D270, 62D181; central decimal file record ===")
ca = J("collection-authority.json")
print("top keys:", list(ca.keys()) if isinstance(ca, dict) else type(ca))
recs = ca.get("collections") or ca.get("records") or ca
if isinstance(recs, dict): recs = list(recs.values())
print("records:", len(recs), "sample keys:", list(recs[0].keys()) if recs else None)
for r in recs:
    s = json.dumps(r)
    if any(x in s for x in ("65F115", "65 F 115", "79F80", "79 F 80", "62D26", "54D270", "62D181")) or ("entral" in s and "ecimal" in s and "ile" in s and len(s) < 1500):
        print("  ", s[:500])

print("\n=== volume-sources-index.json: E5177 / 78D433 / 5403 ===")
vs = J("volume-sources-index.json")
for mc in vs["majorCollections"]:
    s = json.dumps(mc)
    if "5177" in s or "78D433" in s or "5403" in s or "78D443" in s: print("  ", s[:400])
for lot in vs.get("lots", []):
    s = json.dumps(lot)
    if any(x in s for x in ("65F115", "79F80", "62D26", "54D270", "62D181")): print("  lot:", s[:400])

print("\n=== presidential-library-catalog.json: Johnson NSF Vietnam, Kennedy POF/NSF Korea, Ford NSA Presidential Correspondence, Carter WHCF / Brzezinski, Eisenhower Herter ===")
pl = J("presidential-library-catalog.json")
print("top keys:", list(pl.keys()))
s = json.dumps(pl)
for needle in ("National Security File", "President’s Office Files", "President's Office Files", "Presidential Correspondence with Foreign Leaders", "White House Central Files", "Brzezinski", "Herter Papers", "Presidential Country Files"):
    print(f"  '{needle}' present: {needle in s}")
libs = pl.get("libraries") or pl.get("entries") or []
print("  entries:", len(libs) if hasattr(libs, '__len__') else libs)
if isinstance(libs, list) and libs: print("  sample:", json.dumps(libs[0])[:400])

print("\n=== external-citation-index.json: the decimal numbers 751K.00, 851K.392, 795B.00, 893.20, 893.51, 787.00, 811.20200(D) ===")
ec = J("external-citation-index.json")
print("top keys:", list(ec.keys()))
s = json.dumps(ec)
for needle in ("751K.00", "851K.392", "795B.00", "893.20", "893.51", "787.00", "811.20200", "65F115", "62D26", "54D270", "62D181", "79F80", "Herter Papers", "Lot 65 F 115"):
    print(f"  '{needle}' present: {needle in s}")
