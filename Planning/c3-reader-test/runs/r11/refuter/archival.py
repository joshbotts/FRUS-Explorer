import json,sqlite3,re
R="/Applications/FRUS Explorer.app/Contents/Resources"
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
q=lambda s,p=(): con.execute(s,p).fetchall()
cfi=json.load(open(R+"/central-files-index.json")); sf=json.load(open(R+"/series-facts-index.json"))
print("central-files-index keys:",list(cfi.keys())); print("series-facts keys:",list(sf.keys()))
def facts(n):
    r=sf['byNaId'].get(str(n))
    if not r: return "NO series-facts row"
    return "title-heading=%s | %s-%s | access=%s"%(sf['headings'][r['c']] if 'c' in r else None, r.get('y0'),r.get('y1'), sf['statuses'][r['as']] if 'as' in r else None)
print("\n== LOT FILES named in the overview")
for lot,claim in [("64D16","A1 3159 Records Relating to El Salvador NAID 1750062 1958-1975 partly restricted"),("63D351","A1 1586E NSC Policy Papers NAID 2839192 1947-1979 partly restricted"),("66D95","same"),("63D127","A1 3157 Subject and Country Files OCAPA NAID 2363840 1955-1963 possibly restricted"),("59D573","A1 1135 Subject Files Asst Sec ARA NAID 2108779 1957-1959 unrestricted"),("61D279","same"),("62D418","A1 3147 NAID 2068466 1959-1962 partly restricted"),("72D192","A1 5376 Speeches and Statements NAID 631695 1961-1969 unrestricted")]:
    hits=[x for x in cfi['lotFiles'] if x.get('lotNumber')==lot]
    print(lot,"| claim:",claim)
    for h in hits: print("   index: RG",h.get('recordGroup'),"entry",h.get('hmsMlrEntryNumbers'),"NAID",h.get('naId'),"|",h.get('title'),"|",h.get('inclusiveDates') or h.get('dates'),"|",facts(h.get('naId')))
    if not hits: print("   NOT in lotFiles")
print("\n== scope rows that carry those lots (came-from: document_sources; pointed-at: external_citations inherited=0)")
S=set(tuple(l.split()) for l in open("/Users/jbotts/frus-analysis/c3/runs/r11/scope_final.tsv"))
for lot in ("64D16","63D351","66D95","63D127","59D573","61D279","62D418","72D192"):
    cf=[r for r in q("SELECT volume_id,document_id,lot_file,raw_text FROM document_sources WHERE lot_file_norm=?",(lot,)) if (r[0],r[1]) in S]
    pa=[r for r in q("SELECT volume_id,document_id,lot_file,raw_text FROM external_citations WHERE lot_file_norm=? AND inherited=0",(lot,)) if (r[0],r[1]) in S]
    print(lot,"came-from:",[(r[0]+'/'+r[1]) for r in cf],"pointed-at:",[(r[0]+'/'+r[1]) for r in pa])
    for r in cf+pa: print("     ",r[0]+'/'+r[1],"|",r[3][:140].replace("\n"," "))
print("\n== pre-1906 series")
cs=cfi.get('countrySeries')
print("countrySeries type",type(cs).__name__, "len", len(cs) if cs else None)
sample = cs[0] if isinstance(cs,list) else list(cs.items())[0]
print("sample:",json.dumps(sample,ensure_ascii=False)[:600])
txt=json.dumps(cfi)
for ident in ("603720","593313","177380753","177380752","177380736"):
    print(ident, "occurrences in central-files-index:", txt.count(ident))
    for m in list(re.finditer(ident,txt))[:1]:
        print("    ctx:",txt[max(0,m.start()-300):m.end()+200])
print("  series-facts rows:", {i:facts(i) for i in ("603720","593313")})
print("\n== Central Decimal File in series-facts?")
hd=sf['headings']; print("headings containing 'Central' or 'Decimal':",[h for h in hd if re.search(r'central|decimal',h,re.I)][:20])
print("\n== presidential libraries")
plc=json.load(open(R+"/presidential-library-catalog.json")); print("plc keys:",list(plc.keys()) if isinstance(plc,dict) else type(plc))
ptxt=json.dumps(plc,ensure_ascii=False)
for needle in ("George W. Ball","Ball","Dulles","Telephone"):
    print(needle,"occurrences:",ptxt.count(needle))
for m in list(re.finditer(r'George W\. Ball',ptxt))[:2]: print("   ctx:",ptxt[max(0,m.start()-200):m.end()+300])
for m in list(re.finditer(r'Telephone',ptxt))[:3]: print("   ctx:",ptxt[max(0,m.start()-250):m.end()+150])
print("\n== external_citations rows for the two library citations (and in scope?)")
for v,d in (("frus1964-68v31","d205"),("frus1958-60v06","d235")):
    print(v,d,"in scope:",(v,d) in S)
    for r in q("SELECT anchor,repository,collection,raw_text,inherited FROM external_citations WHERE volume_id=? AND document_id=?",(v,d)): print("    ",r)
print("\n== presidentialLibrary anchors among scope pointed-at rows")
for r in q("SELECT volume_id,document_id,repository,collection,raw_text FROM external_citations WHERE anchor='presidentialLibrary' AND inherited=0"):
    if (r[0],r[1]) in S: print("    ",r[0]+'/'+r[1],"|",r[2],"|",r[3],"|",r[4][:120])
print("\n== decimal-class-labels schedule 1910-1949: countries and subjects named")
d=json.load(open(R+"/decimal-class-labels.json")); s=[x for x in d['schedules'] if x['id']=='1910-1949'][0]
for ctry in ("16","24","35","22","14","12","18"): print("  country",ctry,"=",s['countries'].get(ctry))
print("  class 8 subjects .00 =",s['subjects']['8'].get('00'),"; .01 =",s['subjects']['8'].get('01'))
print("  coverage:",d.get('coverage'))
