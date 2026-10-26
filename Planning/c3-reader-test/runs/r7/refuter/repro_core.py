# Refuter's re-derivation of the session's core set from the database and manifest alone (the session's rule, re-coded):
#  Latin American set = non-apparatus document whose heading path names a Latin American country/region, or in a volume whose
#  manifest title does; channel A = my own rerun of the NEAR family (refuter/fts_candidates_refuter.tsv) inside that set;
#  channel B = documents under headings naming "recogni" under Latin American names, minus the 15 hand exclusions
#  (read from out/heading_exclusions.txt, the one hand-made input). Writes refuter/core_refuter.tsv.
import sqlite3, json, re, collections
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"; RF="/Users/jbotts/frus-analysis/c3/runs/r7/refuter/"
con=sqlite3.connect(DB, uri=True)
LATAM=["argentin","bolivia","brazil","chile","colombia","costa rica","cuba","dominican","santo domingo","ecuador","salvador","guatemala","haiti","hayti","honduras","mexic","nicaragua","panama","paraguay","peru","uruguay","venezuela","central america","american republics","western hemisphere","latin america","south america","caribbean","inter-american"]
def is_latam(t):
    t=t.lower()
    if "hawaiian" in t: return False
    return any(k in t for k in LATAM)
man=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
m={v["volumeId"]:v for v in man}
latam_vol={vid for vid,v in m.items() if is_latam(" ".join(v["title"].split()))}
ED2={"frus1951-54IranEd2","frus1969-76ve15p2Ed2"}
app={}
for vid,did,fm,en in con.execute("SELECT volume_id, document_id, is_front_matter, is_editorial_note FROM document_cache"): app[(vid,did)]=(fm or en)
paths={}; nsec=0; nrec=0
def walk(vid, secs, path):
    global nsec, nrec
    for s in secs:
        title=" ".join((s.get("title") or "").split()); p=path+[title]; pj=" > ".join(p); nsec+=1
        if re.search("recogni", pj, re.I): nrec+=1
        for did in s.get("documentIds") or []:
            if (vid,did) not in paths: paths[(vid,did)]=pj
        walk(vid, s.get("subsections") or [], p)
nvol=0
for vid,sj in con.execute("SELECT volume_id, structure_json FROM volume_structures"):
    nvol+=1; walk(vid, json.loads(sj).get("sections",[]), [])
print("manifest volumes:", len(man), "| volume_structures:", nvol, "| section rows:", nsec, "| sections naming recogni (path):", nrec)
latam={}
for (vid,did),pj in paths.items():
    if app.get((vid,did),1) or vid in ED2: continue
    if is_latam(pj) or vid in latam_vol: latam[(vid,did)]=pj
for (vid,did),ap in app.items():
    if ap or (vid,did) in paths or vid in ED2: continue
    if vid in latam_vol: latam[(vid,did)]="(no heading)"
print("Latin American non-apparatus documents:", len(latam), "| latam volumes by title:", len(latam_vol))
heads={k:p for k,p in latam.items() if re.search("recogni", p, re.I) and is_latam(p)}
print("under headings naming recognition (raw):", len(heads), "distinct (volume, path):", len({(k[0],p) for k,p in heads.items()}))
excl=[l.rstrip("\n").split("\t") for l in open("/Users/jbotts/frus-analysis/c3/runs/r7/out/heading_exclusions.txt") if l.strip() and not l.startswith("#")]
def excluded(vid,p): return any(vid==ev and es in p for ev,es in excl)
cur={k:p for k,p in heads.items() if not excluded(k[0],p)}
print("exclusion rules:", len(excl), "| curated heading docs:", len(cur), "distinct (volume, path):", len({(k[0],p) for k,p in cur.items()}))
# which exclusion rules removed what
rem=collections.Counter()
for k,p in heads.items():
    for ev,es in excl:
        if k[0]==ev and es in p: rem[(ev,es)]+=1
print("removed by each rule:", sorted(rem.items()))
fts=set()
for l in open(RF+"fts_candidates_refuter.tsv"):
    v,d=l.rstrip("\n").split("|"); fts.add((v,d))
fts_na={k for k in fts if not app.get(k,1) and k[0] not in ED2}
A={k for k in fts_na if k in latam}; B=set(cur); core=A|B
print("FTS hits all:", len(fts), "non-apparatus non-Ed2:", len(fts_na))
print(f"A = {len(A)} docs in {len({v for v,_ in A})} volumes | B = {len(B)} | A&B = {len(A&B)} | A only {len(A-B)} | B only {len(B-A)} | core = {len(core)} in {len({v for v,_ in core})} volumes")
dates={(v,d):(iso or "") for v,d,iso in con.execute("SELECT volume_id, document_id, date_iso FROM document_dates")}
with open(RF+"core_refuter.tsv","w") as f:
    f.write("volume_id\tdocument_id\tdate_iso\tin_fts\tin_heading\n")
    for k in sorted(core): f.write(f"{k[0]}\t{k[1]}\t{dates.get(k,'')}\t{int(k in A)}\t{int(k in B)}\n")
# compare with the session's core_set.tsv
sess=[l.rstrip("\n").split("\t") for l in open("/Users/jbotts/frus-analysis/c3/runs/r7/out/core_set.tsv")][1:]
sA={(v,d) for v,d,iso,a,b,p in sess if a=="1"}; sB={(v,d) for v,d,iso,a,b,p in sess if b=="1"}
print("session A == mine:", sA==A, "| session B == mine:", sB==B, "| sym diffs:", len(sA^A), len(sB^B))
# decade shape for channel A
den=dict(con.execute("SELECT substr(d.date_iso,1,3)||'0s', COUNT(*) FROM document_dates d JOIN document_cache c ON c.volume_id=d.volume_id AND c.document_id=d.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso IS NOT NULL AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') GROUP BY 1").fetchall())
cnt=collections.Counter((dates.get(k,"")[:3]+"0s") if dates.get(k) else "undated" for k in A)
for dec in sorted(cnt): print(f"  {dec}: A={cnt[dec]} / {den.get(dec)} = {1000*cnt[dec]/den[dec]:.2f} per 1,000")
print("A dated 1861-1908:", sum(1 for k in A if '1861'<=dates.get(k,'')[:4]<='1908'))
allA=[dates[k] for k in A if dates.get(k)]; allC=[dates[k] for k in core if dates.get(k)]
print("A date span:", min(allA), max(allA), "| core date span:", min(allC), max(allC))
