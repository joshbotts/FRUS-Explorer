# Confirm each archival identifier the bottom line's second paragraph names against the bundled artifacts.
import json, re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+"central-files-index.json")); sf=json.load(open(R+"series-facts-index.json")); vs=json.load(open(R+"volume-sources-index.json")); pl=json.load(open(R+"presidential-library-catalog.json"))
def fold(s): return re.sub(r'[^0-9A-Za-z]','',s).upper()
lots={}
for l in cf['lotFiles']: lots.setdefault(fold(l['lotNumber']),[]).append(l)
print("lotFiles entries:", len(cf['lotFiles']), "| sample lotNumbers:", [l['lotNumber'] for l in cf['lotFiles'][:8]])
L=sf['legend']['keys']
def decode(row):
    out={}
    for k,v in row.items():
        spec=L.get(k)
        if not spec: out[k]=v; continue
        f=spec['field']
        if spec['kind']=='index': out[f]=sf[spec['into']][v]
        elif spec['kind']=='indexList': out[f]=[sf[spec['into']][i] for i in v]
        else: out[f]=v
    return out
checks=[("62 D 1","2838992","Records Relating to Activities with the National Security Council",["A1 1583E","A1 1583F"],1948,1961,"Restricted"),
        ("62 D 430","2839191","Subject and Special Files",["A1 1586C"],1953,1961,"Restricted"),
        ("63 D 351","2839192","Records Relating to National Security Council Policy Papers",["A1 1586E"],1947,1979,"Restricted"),
        ("66 D 95","2839192","Records Relating to National Security Council Policy Papers",["A1 1586E"],1947,1979,"Restricted"),
        ("53 D 26","2108774","Subject Files",["A1 1130"],1949,1953,"Unrestricted"),
        ("64 D 199","602231","Memoranda of Conversation",["A1 1566"],1953,1964,"Unrestricted"),
        ("64 D 16","1750062","Records Relating to El Salvador",["A1 3159"],1958,1975,"Restricted"),
        ("81 D 64","27499857","Assistant Secretary's Files",["UD-14D 61"],1978,1981,"Restricted"),
        ("61 D 279","2108779","Subject Files",["A1 1135"],1957,1959,"Unrestricted")]
print("\n-- lot files (overview claim -> central-files-index.lotFiles -> series-facts-index.byNaId)")
for lot,naid,title,entries,y0,y1,acc in checks:
    ls=lots.get(fold(lot),[])
    row=sf['byNaId'].get(naid); dec=decode(row) if row else None
    print(f"Lot {lot}: lotFiles matches={[(l['naId'],l['title'][:60],l.get('hmsMlrEntryNumbers'),l.get('matchType')) for l in ls]}")
    print(f"   claim NAID {naid} title~'{title}' entries {entries} {y0}-{y1} {acc}")
    print(f"   byNaId[{naid}] = {json.dumps(dec, ensure_ascii=False)[:400] if dec else None}")
    ok = any(l['naId']==naid for l in ls) and dec is not None and dec.get('inclusiveStartYear')==y0 and dec.get('inclusiveEndYear')==y1 and all(e in (ls[0].get('hmsMlrEntryNumbers') or []) for l in ls[:1] for e in entries) and any(title.lower()[:25] in l['title'].lower() for l in ls) and acc.lower() in str(dec.get('accessStatus','')).lower()
    print("   =>", "CONFIRMED" if ok else "CHECK BY HAND")
print("\n-- record group")
rg=vs['recordGroups'].get('59'); print("RG 59:", rg)
print("\n-- presidential libraries (claim -> presidential-library-catalog.json)")
for cited, want_naid, want_title in [("Kennedy Library",1164,"National Security Files"),("Johnson Library",567979,"National Security File"),("Carter Library",623746,"National Security Council Institutional Files")]:
    libs=[l for l in pl['libraries'] if l['citedAs']==cited]
    for l in libs:
        hits=[c for c in l['collections'] if c.get('naId')==want_naid]
        print(f"{cited} (prefix {l['prefix']}, {len(l['collections'])} collections): naId {want_naid} ->", [(c['identifier'], c['title']) for c in hits] or "NOT FOUND")
        alt=[(c['identifier'],c['naId'],c['title']) for c in l['collections'] if 'National Security' in c['title']]
        print("   collections titled National Security*:", alt[:8])
# unmatched claims: Nixon NSC Files, Carter National Security Affairs, Eisenhower Whitman File
print("\n-- claimed unmatched:")
for cited, kw in [("Nixon","NSC"),("Carter Library","National Security Affairs"),("Eisenhower Library","Whitman")]:
    libs=[l for l in pl['libraries'] if cited.split()[0] in l['citedAs']]
    for l in libs:
        print(f"{l['citedAs']}: collections mentioning '{kw}':", [(c['identifier'],c['naId'],c['title'][:60]) for c in l['collections'] if kw.lower() in c['title'].lower()][:6])
print("\n-- subject-numeric glosses")
sn=json.load(open(R+"subject-numeric-labels.json")); print("keys:", list(sn.keys())[:10]); print("coverage:", json.dumps(sn.get('coverage'))[:300])
sch=sn.get('schedules') or sn
for name,s in (sch.items() if isinstance(sch,dict) else []):
    if not isinstance(s,dict): continue
    pol=s.get('subjects',{}).get('POL') or s.get('POL') or {}
    print(name, "POL 15:", pol.get('15') if isinstance(pol,dict) else None, "| POL 16:", pol.get('16') if isinstance(pol,dict) else None, "| POL 23-9:", (pol.get('23-9') or pol.get('23–9')) if isinstance(pol,dict) else None, "| POL 26:", pol.get('26') if isinstance(pol,dict) else None)
print("\n-- BL3 inferred shelf: Despatches from U.S. Ministers to Mexico file unit NAID 177380741")
for cs in cf['countrySeries']:
    s=json.dumps(cs)
    if '177380741' in s:
        print(json.dumps(cs, ensure_ascii=False)[:500]); break
else: print("NOT FOUND in countrySeries")
