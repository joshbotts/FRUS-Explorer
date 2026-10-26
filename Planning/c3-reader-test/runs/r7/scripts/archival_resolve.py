# Resolves the core set's archival channels through the bundled JSON:
#  (a) decimal-class glosses for the came-from channel, gated by decimal-class-labels.json coverage.glossableYears and each document's date;
#  (b) presidential-library series for the came-from collections (presidential-library-catalog.json);
#  (c) collection-usage-index.json ranked collections for the SCOPE VOLUMES (volume-scope channel, not the document set), named via collection-authority.json,
#      with NAIDs from central-files-index.json lotFiles and facts from series-facts-index.json;
#  (d) external-citation-index.json ranked pointed-at targets for the scope volumes (what the editors cited and did not print).
import json, collections, sqlite3, re
B="/Applications/FRUS Explorer.app/Contents/Resources/"; R="/Users/jbotts/frus-analysis/c3/runs/r7/out/"
J=lambda fn: json.load(open(B+fn))
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows=[l.rstrip("\n").split("\t") for l in open(R+"core_set.tsv")][1:]
core={(v,d):iso for v,d,iso,a,b,p in rows}
scope_vols=sorted({v for v,d in core})
print("scope volumes:", len(scope_vols))
# (a) decimal glosses
dcl=J("decimal-class-labels.json"); spans=dcl["coverage"]["glossableYears"]
sched={s["id"]:s for s in dcl["schedules"]}
def schedule_for(year):
    for sp in spans:
        if sp["startYear"]<=year<=sp["endYear"]: return sched[sp["scheduleId"]]
    return None
con.execute("CREATE TEMP TABLE core(volume_id TEXT, document_id TEXT, PRIMARY KEY(volume_id, document_id))")
con.executemany("INSERT INTO core VALUES (?,?)", list(core))
cls=collections.defaultdict(lambda: collections.Counter())
for v,d,dc in con.execute("SELECT s.volume_id, s.document_id, s.decimal_class FROM document_sources s JOIN core c ON c.volume_id=s.volume_id AND c.document_id=s.document_id WHERE s.decimal_class IS NOT NULL"):
    iso=core[(v,d)]; y=int(iso[:4]) if iso[:4].isdigit() else None
    sc=schedule_for(y) if y else None
    cls[dc][sc["id"] if sc else "no-gloss"]+=1
out=open(R+"archival_decimal_gloss.tsv","w"); out.write("decimal_class\tn_total\tn_glossable_1910_1949\tn_other\tgloss (1910-1949 schedule only)\n")
def gloss(dc, sc):
    m=re.match(r"^(\d)(\d\d)\.(\w+)$", dc)
    if not m: return "(unparsed key)"
    c,cc,rest=m.groups()
    cname=sc["classes"].get(c,"?"); country=sc["countries"].get(cc,"?")
    subj=sc["subjects"].get(c,{}).get(rest) if isinstance(sc["subjects"].get(c),dict) else None
    return f"class {c} {cname}; country {cc} {country}; subject {rest} {subj or '(no subject label in schedule)'}"
top=sorted(cls.items(), key=lambda kv:-sum(kv[1].values()))[:25]
print("## (a) came-from decimal classes, glossed only for documents dated 1910-1949 (schedule RG 59 Classification 1910-1949)")
for dc,cnt in top:
    g=cls[dc].get("1910-1949",0); o=sum(cnt.values())-g
    gl=gloss(dc, sched["1910-1949"]) if g else "(no document in a glossable year)"
    line=f"{dc}\t{sum(cnt.values())}\t{g}\t{o}\t{gl}"; print(line); out.write(line+"\n")
out.close()
# (b) presidential library series
plc=J("presidential-library-catalog.json")
print("## (b) presidential-library series behind the came-from collections")
want={"Kennedy Library":("National Security Files",["Country Files","Countries"]),"Johnson Library":("National Security Files",["Latin America Country Files","Country File"]),"Nixon":("National Security Files (Nixon Administration)",[]),"Carter Library":("Records of the Office of the National Security Advisor (Carter Administration)",["Country File","Brzezinski Material"])}
for lib in plc["libraries"]:
    if lib["citedAs"] in want:
        title,keys=want[lib["citedAs"]]
        for col in lib["collections"]:
            if (col.get("title") or "")==title:
                print(f"  {lib['citedAs']}: {col['title']} (identifier {col.get('identifier')}, NAID {col.get('naId')}, {col.get('statedSeriesCount')} series)")
                for s in col.get("series",[]):
                    if not keys or any(k.lower() in (s.get('title') or '').lower() for k in keys):
                        print(f"     series: {s.get('title')} | NAID {s.get('naId')} | {s.get('inclusiveDates')}")
# (c) collection-usage ranking for the scope volumes
u=J("collection-usage-index.json"); ca=J("collection-authority.json"); cf=J("central-files-index.json"); sf=J("series-facts-index.json")
vidx={v:i for i,v in enumerate(u["volumes"])}; scope_idx={vidx[v] for v in scope_vols if v in vidx}
auth={c["id"]:c for c in ca["collections"]}
lots={l["lotNumber"]:l for l in cf["lotFiles"]}
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
rank=[]
for col in u["collections"]:
    cid=u["collectionIds"][col["k"]]
    n=sum(c for c,vi in zip(col["n"],col["v"]) if vi in scope_idx)
    nv=sum(1 for vi in col["v"] if vi in scope_idx)
    if n: rank.append((n,nv,cid))
rank.sort(reverse=True)
print(f"## (c) collection-usage-index: top collections cited in the {len(scope_idx)} scope volumes (volume-scope channel; footnote citations, printed or not)")
outc=open(R+"archival_usage_scope.tsv","w"); outc.write("notes\tvolumes\tcollection_id\tname\trepository\tNAID\tRG\tentry\tseries_facts\n")
for n,nv,cid in rank[:30]:
    a=auth.get(cid,{}); name=a.get("name",cid); repo=a.get("repository","")
    lot=cid.split(":",1)[1] if cid.startswith("lot:") else None
    L=lots.get(lot) if lot else None
    naid=L["naId"] if L else a.get("naId")
    entry=",".join(L.get("hmsMlrEntryNumbers",[])) if L else ""
    rg=L.get("recordGroup","") if L else ""
    f=facts(naid) if naid else "(no NAID in the bundle)"
    line=f"{n}\t{nv}\t{cid}\t{name[:90]}\t{repo}\t{naid or ''}\t{rg}\t{entry}\t{f}"
    print("  "+line[:400]); outc.write(line+"\n")
outc.close()
# volume categories for the scope
cat=collections.Counter()
for vc in u["volumeCategories"]:
    cname=u["categories"][vc["k"]]
    cat[cname]+=sum(c for c,vi in zip(vc["n"],vc["v"]) if vi in scope_idx)
print("## (c2) footnote citations in the scope volumes by category:", cat.most_common())
# (d) external-citation-index targets for scope volumes
e=J("external-citation-index.json")
evidx={v:i for i,v in enumerate(e["volumes"])}; escope={evidx[v] for v in scope_vols if v in evidx}
print(f"## (d) external-citation-index: scope volumes present in it: {len(escope)} of {len(scope_vols)}; coverage: {json.dumps(e['coverage'])[:600]}")
rank=[]
for t in e["targets"]:
    tid=e["targetIds"][t["k"]]
    n=sum(c for c,vi in zip(t["n"],t["v"]) if vi in escope); nv=sum(1 for vi in t["v"] if vi in escope)
    if n: rank.append((n,nv,tid))
rank.sort(reverse=True)
outd=open(R+"archival_pointed_at_scope.tsv","w"); outd.write("citations\tvolumes\ttarget_id\tname\tNAID\tRG\tentry\tseries_facts\n")
for n,nv,tid in rank[:25]:
    a=auth.get(tid,{}); name=a.get("name",tid)
    lot=tid.split(":",1)[1] if tid.startswith("lot:") else None
    L=lots.get(lot) if lot else None
    naid=L["naId"] if L else a.get("naId"); entry=",".join(L.get("hmsMlrEntryNumbers",[])) if L else ""; rg=L.get("recordGroup","") if L else ""
    line=f"{n}\t{nv}\t{tid}\t{name[:90]}\t{naid or ''}\t{rg}\t{entry}\t{facts(naid) if naid else '(no NAID in the bundle)'}"
    print("  "+line[:400]); outd.write(line+"\n")
outd.close()
