# Refuter extras: channel-one/two claims from the index over MY tier-2 set; presidential-library catalogue; pre-1906 series;
# manifest titles; N05 narrow shares; sample-40 literal share.
import sqlite3, re, json, collections
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c=sqlite3.connect(DB,uri=True)
R="/Applications/FRUS Explorer.app/Contents/Resources/"
ED2=('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
CUB=re.compile(r"\bCub(?:a|an|ans)\b")
rows=c.execute("""SELECT d.volume_id, d.document_id, dd.date_iso, d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
 JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
 WHERE frus_documents MATCH 'cuba OR cuban' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (?,?) AND dd.date_iso>='1870' AND dd.date_iso<'1990'""",ED2).fetchall()
tier1=sorted((v,d) for v,d,dt,b in rows)
tier2=[(v,d,dt,b) for v,d,dt,b in rows if len(CUB.findall(b))>=5]
c.execute("CREATE TEMP TABLE sc(volume_id TEXT, document_id TEXT, date TEXT)")
c.executemany("INSERT INTO sc VALUES(?,?,?)",[(v,d,dt) for v,d,dt,b in tier2])
def band(dt):
    y=int(dt[:4]); return "1870-1899" if y<1900 else "1900-1939" if y<1940 else "1940-1957" if y<1958 else "1958-1989"
print("== CHANNEL ONE (document_sources) over tier-2 (%d docs)"%len(tier2))
print("1900-1957: docs", c.execute("SELECT COUNT(*) FROM sc WHERE date>='1900' AND date<'1958'").fetchone()[0],
      "; with a source row", c.execute("SELECT COUNT(*) FROM sc s JOIN document_sources ds USING(volume_id,document_id) WHERE s.date>='1900' AND s.date<'1958'").fetchone()[0],
      "; citation_era=decimal & RG 59", c.execute("SELECT COUNT(*) FROM sc s JOIN document_sources ds USING(volume_id,document_id) WHERE s.date>='1900' AND s.date<'1958' AND ds.citation_era='decimal' AND ds.record_group='59'").fetchone()[0])
print("1958-1989 came-from by (era, repository, RG):")
for r in c.execute("SELECT ds.citation_era, ds.repository, ds.record_group, COUNT(*) FROM sc s JOIN document_sources ds USING(volume_id,document_id) WHERE s.date>='1958' GROUP BY 1,2,3 ORDER BY 4 DESC LIMIT 12"): print("   ",r)
print("1958-1989 came-from lot files (lot_file_norm, series_name, n):")
for r in c.execute("SELECT ds.lot_file_norm, ds.series_name, COUNT(*) FROM sc s JOIN document_sources ds USING(volume_id,document_id) WHERE s.date>='1958' AND ds.citation_era='lot_file' GROUP BY 1,2 ORDER BY 3 DESC LIMIT 12"): print("   ",r)
print("named lots in came-from (any band):")
for lot in ["65D438","64D199","65D330","62D24","66D501","66D95","65D212"]:
    print("   ",lot, c.execute("SELECT COUNT(*), MIN(s.date), MAX(s.date) FROM sc s JOIN document_sources ds USING(volume_id,document_id) WHERE ds.lot_file_norm=?",(lot,)).fetchone())
print("came-from structured collections (repository, series_name, n), all bands:")
for r in c.execute("SELECT ds.repository, ds.series_name, COUNT(*) FROM sc s JOIN document_sources ds USING(volume_id,document_id) WHERE ds.citation_era='structured' GROUP BY 1,2 ORDER BY 3 DESC LIMIT 14"): print("   ",r)
print("came-from repositories matching the libraries and CIA (any era):")
for pat in ["%Kennedy%","%Johnson%","%Carter%","%Nixon%","%Eisenhower%","%Central Intelligence%"]:
    print("   ",pat, c.execute("SELECT COUNT(*) FROM sc s JOIN document_sources ds USING(volume_id,document_id) WHERE ds.repository LIKE ?",(pat,)).fetchone()[0],
          c.execute("SELECT ds.series_name, COUNT(*) FROM sc s JOIN document_sources ds USING(volume_id,document_id) WHERE ds.repository LIKE ? GROUP BY 1 ORDER BY 2 DESC LIMIT 3",(pat,)).fetchall())
print("== CHANNEL TWO (external_citations) over tier-2")
print("rows by band:", c.execute("SELECT CASE WHEN s.date<'1900' THEN '1870-1899' WHEN s.date<'1940' THEN '1900-1939' WHEN s.date<'1958' THEN '1940-1957' ELSE '1958-1989' END, COUNT(*) FROM sc s JOIN external_citations ec USING(volume_id,document_id) GROUP BY 1").fetchall())
print("anchors:", c.execute("SELECT ec.anchor, COUNT(*) FROM sc s JOIN external_citations ec USING(volume_id,document_id) GROUP BY 1 ORDER BY 2 DESC").fetchall())
print("lots pointed at (rows, distinct docs):")
for r in c.execute("SELECT ec.lot_file_norm, COUNT(*), COUNT(DISTINCT s.volume_id||'/'||s.document_id) FROM sc s JOIN external_citations ec USING(volume_id,document_id) WHERE ec.anchor='lotFile' GROUP BY 1 ORDER BY 2 DESC LIMIT 10"): print("   ",r)
for lot in ["66D95","65D438","62D24","65D330","64D199","65D212"]:
    print("   named lot",lot, c.execute("SELECT COUNT(*), COUNT(DISTINCT s.volume_id||'/'||s.document_id), MIN(s.date), MAX(s.date) FROM sc s JOIN external_citations ec USING(volume_id,document_id) WHERE ec.lot_file_norm=?",(lot,)).fetchone())
print("libraries pointed at (repository, collection, rows):")
for r in c.execute("SELECT ec.repository, ec.collection, COUNT(*) FROM sc s JOIN external_citations ec USING(volume_id,document_id) WHERE ec.anchor='presidentialLibrary' GROUP BY 1,2 ORDER BY 3 DESC LIMIT 8"): print("   ",r)
print("central-file classes pointed at:", c.execute("SELECT COUNT(*) FROM sc s JOIN external_citations ec USING(volume_id,document_id) WHERE ec.anchor='centralFileClass'").fetchone())
print("docs with >=1 row:", c.execute("SELECT COUNT(DISTINCT s.volume_id||'/'||s.document_id) FROM sc s JOIN external_citations ec USING(volume_id,document_id)").fetchone())
print("earliest external_citations row (whole index) with its document:", c.execute("SELECT dd.date_iso, ec.volume_id, ec.document_id, ec.anchor FROM external_citations ec JOIN document_dates dd USING(volume_id,document_id) WHERE dd.date_iso IS NOT NULL ORDER BY 1 LIMIT 2").fetchall())
print("== DECIMAL CLASSES came-from, tier-2 dated <1958, citation_era=decimal:")
for r in c.execute("SELECT ds.decimal_class, COUNT(*), MIN(s.date), MAX(s.date) FROM sc s JOIN document_sources ds USING(volume_id,document_id) WHERE ds.citation_era='decimal' AND s.date<'1958' GROUP BY 1 ORDER BY 2 DESC LIMIT 8"): print("   ",r)
print("== PRESIDENTIAL LIBRARY CATALOGUE")
pl=json.load(open(R+"presidential-library-catalog.json"))
print("keys:",list(pl.keys()) if isinstance(pl,dict) else type(pl))
def walk(o,path="",out=None):
    if isinstance(o,dict):
        for k,v in o.items(): walk(v,path+"/"+k,out)
    elif isinstance(o,list):
        for i,v in enumerate(o): walk(v,path+"[%d]"%i,out)
    elif isinstance(o,str):
        if re.search(r"National Security Files?$|National Security Affairs$|Whitman File|NSC Files",o): out.append((path,o))
hits=[]; walk(pl,"",hits)
for h in hits[:40]: print("   ",h)
print("== PRE-1906 SERIES (central-files-index countrySeries)")
ci=json.load(open(R+"central-files-index.json"))
cs=ci["countrySeries"]
print("countrySeries type:",type(cs), (list(cs.keys())[:10] if isinstance(cs,dict) else len(cs)))
txt=json.dumps(cs)
for naid in ["177380726","603720","177380758","183303928","183303950","593313"]:
    i=txt.find(naid); print("   ",naid, "present" if i>=0 else "ABSENT", txt[max(0,i-200):i+60].replace("\n"," ") if i>=0 else "")
print("== MANIFEST TITLES")
man=json.load(open(R+"manifest.json"))
print("manifest entry keys:",list(man[0].keys()))
title={}
for x in man:
    vid=x.get("id") or x.get("volumeId") or x.get("volume_id")
    title[vid]=re.sub(r"\s+"," ",x.get("title") or x.get("fullTitle") or "")
printed={"frus1874":"Papers Relating to the Foreign Relations of the United States, 1874","frus1898":"Papers Relating to the Foreign Relations of the United States, 1898","frus1902":"Papers Relating to the Foreign Relations of the United States, 1902","frus1918":"Papers Relating to the Foreign Relations of the United States, 1918","frus1933v05":"Foreign Relations of the United States, Diplomatic Papers, 1933, The American Republics, Volume V","frus1934v05":"Foreign Relations of the United States, Diplomatic Papers, 1934, The American Republics, Volume V","frus1941v07":"Foreign Relations of the United States, Diplomatic Papers, 1941, The American Republics, Volume VII","frus1948v09":"Foreign Relations of the United States, 1948, The Western Hemisphere, Volume IX","frus1950v02":"Foreign Relations of the United States, 1950, The United Nations; The Western Hemisphere, Volume II","frus1952-54v04":"Foreign Relations of the United States, 1952–1954, The American Republics, Volume IV","frus1958-60v06":"Foreign Relations of the United States, 1958–1960, Cuba, Volume VI","frus1961-63v11":"Foreign Relations of the United States, 1961–1963, Volume XI, Cuban Missile Crisis and Aftermath","frus1969-76ve10":"Foreign Relations of the United States, 1969–1976, Volume E–10, Documents on American Republics, 1969–1972","frus1977-80v23":"Foreign Relations of the United States, 1977–1980, Volume XXIII, Mexico, Cuba, and the Caribbean","frus1977-80v01":"Foreign Relations of the United States, 1977–1980, Volume I, Foundations of Foreign Policy","frus1981-88v03":"Foreign Relations of the United States, 1981–1988, Volume III, Soviet Union, January 1981–January 1983"}
for v,p in printed.items():
    t=title.get(v); print("   ",("EXACT" if t==p else "short"),v,"| printed:",p,"| manifest:",t)
for y in ["1874","1898","1902","1918"]:
    print("    volumes whose id starts with frus%s:"%y,[vid for vid in title if vid and vid.startswith("frus"+y)])
print("== N05 NARROW (scan2.py's regexes over my tier-2 set)")
SEC2=re.compile(r"\b(secur\w*|strategic\w*|defen[cs]\w*|menace\w*|Soviet\w*|missile\w*|naval|Monroe|European power\w*)\b",re.I)
PRO2=re.compile(r"\b(sugar\w*|commerc\w*|trade|tariff\w*|reciproc\w*|export\w*|import\w*|investment\w*|market\w*|prosper\w*|quota\w*|tobacco)\b",re.I)
B=collections.defaultdict(lambda:[0,0,0])
for v,d,dt,b in tier2:
    s=p=False
    for m in CUB.finditer(b):
        w=b[max(0,m.start()-250):m.start()+250]; s=s or bool(SEC2.search(w)); p=p or bool(PRO2.search(w))
    x=B[band(dt)]; x[0]+=1; x[1]+=s; x[2]+=p
for k in ["1870-1899","1900-1939","1940-1957","1958-1989"]:
    x=B[k]; print("   %s | %d | security %d (%.3f) | prosperity %d (%.3f)"%(k,x[0],x[1],x[1]/x[0],x[2],x[2]/x[0]))
print("== SAMPLE 40 literal share (sorted hit list, every len/40th)")
step=len(tier1)/40.0; samp=[tier1[int(i*step)] for i in range(40)]
strict=re.compile(r"\bCub(?:a|an)\b",re.I); tol=re.compile(r"\bCub(?:a|an|ans|as)?\b",re.I); s=t=0
for v,d in samp:
    r=c.execute("SELECT header||' '||ifnull(dateline,'')||' '||ifnull(source_note,'')||' '||body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    s+=bool(strict.search(r)); t+=bool(tol.search(r))
print("   hit list %d; STRICT %d of 40; TOLERANT %d of 40"%(len(tier1),s,t))
sess=open("/Users/jbotts/frus-analysis/c3v/runs/v1/sample40_cuba.txt").read().split()
print("   same 40 as the session's sample40_cuba.txt:", sess==["%s/%s"%p for p in samp])
