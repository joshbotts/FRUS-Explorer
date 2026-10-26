# Refuter: confirm every archival identifier in the overview's bottom-line paragraph 2 against the bundled artifacts.
import json, re, collections
B="/Applications/FRUS Explorer.app/Contents/Resources/"
J=lambda fn: json.load(open(B+fn))
cf=J("central-files-index.json"); plc=J("presidential-library-catalog.json"); sf=J("series-facts-index.json"); ca=J("collection-authority.json")
print("central-files-index keys:", list(cf.keys()))
print("series-facts keys:", list(sf.keys()), "| legend:", json.dumps(sf.get("legend"))[:600])
print("collection-authority keys:", list(ca.keys()))
print("presidential-library-catalog keys:", list(plc.keys()))
# ---- (1) Despatches / Notes series NAIDs via countrySeries
want_naids={"189098908":"Despatches Mexico 1823-1906","189346553":"Despatches Peru 1826-1906","188290667":"Despatches Chile 1823-1906","188942579":"Despatches Venezuela 1835-1906","188973924":"Despatches Haiti 1862-1906","189314921":"Despatches Bolivia 1848-1906"}
found=collections.defaultdict(list)
for cs in cf["countrySeries"]:
    for r in cs.get("rolls",[]):
        for key in ("naId","fileUnitNaId","seriesNaId"):
            val=str(r.get(key)) if r.get(key) is not None else None
            if val in want_naids:
                found[val].append((cs.get("displayName"), cs.get("category"), key, r.get("fileUnitTitle"), r.get("title"), r.get("startISO"), r.get("endISO")))
    for key in ("naId","seriesNaId"):
        val=str(cs.get(key)) if cs.get(key) is not None else None
        if val in want_naids: found[val].append((cs.get("displayName"), cs.get("category"), "series-level "+key, cs.get("inclusiveDates")))
print("\n## Despatches series NAIDs")
for n,label in want_naids.items():
    hits=found.get(n,[])
    uniq=[]
    for h in hits:
        if h not in uniq: uniq.append(h)
    print(f"  {n} ({label}): {len(hits)} hit rows; distinct: {uniq[:3]}")
# also check the series title/dates as the overview prints them
print("\n  countrySeries sample row keys:", sorted(cf["countrySeries"][0]["rolls"][0].keys()) if cf["countrySeries"] and cf["countrySeries"][0].get("rolls") else None)
print("  countrySeries top-level keys:", sorted(cf["countrySeries"][0].keys()))
# ---- (2) presidential library series
want_pl={"193236":"Kennedy NSF Country Files 1961-1963","567985":"Johnson NSF Latin America Country Files 1963-1969","572235":"Nixon National Security Files 1969-1974","560151":"Carter NSA Brzezinski Country Files 1977-1981","12024796":"Reagan NSC Latin American Affairs Directorate","12025085":"Reagan LAAD General Office Files 1983-1989","1164":"Kennedy NSF collection","567979":"Johnson NSF collection","560131":"Carter NSA collection"}
print("\n## Presidential-library NAIDs")
for lib in plc["libraries"]:
    for col in lib.get("collections",[]):
        cn=str(col.get("naId"))
        if cn in want_pl: print(f"  COLLECTION {cn} ({want_pl[cn]}): {lib.get('citedAs')} | {col.get('title')} | id {col.get('identifier')} | dates {col.get('inclusiveDates')} | access {col.get('access') or col.get('accessStatus')} | keys {sorted(col.keys())}")
        for s in col.get("series",[]):
            sn=str(s.get("naId"))
            if sn in want_pl: print(f"  SERIES {sn} ({want_pl[sn]}): {lib.get('citedAs')} > {col.get('title')} (coll NAID {col.get('naId')}) > {s.get('title')} | dates {s.get('inclusiveDates')} | keys {sorted(s.keys())}")
# ---- (3) lot files
lots={l["lotNumber"]:l for l in cf["lotFiles"]}
print("\n## lotFiles count:", len(lots), "| sample keys:", sorted(next(iter(lots.values())).keys()))
leg=sf["legend"]["keys"]
def facts(naid):
    r=sf["byNaId"].get(str(naid))
    if not r: return "(no series-facts row)"
    def idx(key, into):
        val=r.get(key)
        if val is None: return None
        arr=sf[into]
        return [arr[i] for i in val] if isinstance(val,list) else arr[val]
    return f"creator={idx('c','headings')}; extent={r.get('x')}; inclusive={r.get('y0')}-{r.get('y1')}; access={idx('as','statuses')}; restrictions={idx('ar','restrictions')}; unit={idx('ru','referenceUnits')}"
claims=[("65 D 438","A1 3053","27022950","1962–1963","restricted in part","S/S Files"),
        ("53 D 26","A1 1130","2108774","1949–1953","unrestricted","ARA files"),
        ("59 D 573","A1 1135","2108779","1957–1959","unrestricted","ARA"),
        ("57 D 295","A1 1134","2108778","1953–1956","unrestricted","Holland Files"),
        ("60 D 665","A1 5474A","2660902","1951–1960","unrestricted","OAS Files"),
        ("66 D 95","A1 1586E","2839192","1947–1979","restricted in part","S/S-NSC (Miscellaneous) Files"),
        ("81D113","P 14","1487627","1975–1981","restricted in part","D Files, Deputy Secretary"),
        ("81D64","UD-14D 61","27499857","1978–1981","fully restricted","Nicaragua/El Salvador Working Files")]
def find_lot(num):
    k=num.replace(" ","")
    for ln,l in lots.items():
        if ln.replace(" ","").upper()==k.upper(): return ln,l
    return None,None
print("\n## Lot files")
for num,entry,naid,dates,access,name in claims:
    ln,l=find_lot(num)
    if not l: print(f"  {num}: NOT in lotFiles"); continue
    print(f"  {num} -> key {ln!r}: naId={l.get('naId')} (claimed {naid}) entries={l.get('hmsMlrEntryNumbers')} (claimed {entry}) RG={l.get('recordGroup')} title={str(l.get('title') or l.get('seriesTitle'))[:100]} office={str(l.get('office') or l.get('creator'))[:80]}")
    print(f"      facts: {facts(l.get('naId'))}  | claimed dates {dates}, access {access}, name {name}")
# ---- (4) Central Decimal File: any NAID in bundle?
print("\n## Central Decimal File identifiers in the bundle")
for c in ca["collections"]:
    n=(c.get("name") or "")
    if re.search(r"central (decimal )?file", n, re.I) and not re.search(r"foreign policy", n, re.I):
        print("  authority:", c.get("id"), "|", n[:80], "| repo", c.get("repository"), "| naId", c.get("naId"), "| keys", sorted(c.keys()))
print("  central-files-index numericalFile/decimalFile keys:", [k for k in cf.keys()])
for k in cf:
    v=cf[k]
    if isinstance(v,dict): print("   ", k, "->", {kk:(str(vv)[:80]) for kk,vv in list(v.items())[:8]})
    elif isinstance(v,list): print("   ", k, "-> list of", len(v), "first keys", sorted(v[0].keys()) if v and isinstance(v[0],dict) else str(v[:3])[:100])
