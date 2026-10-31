import sqlite3, json, re
RUN="/Users/jbotts/frus-analysis/c3s/runs/s5/"
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
db=sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
ov=open(RUN+"overview.md").read()
cited=[]
for m in re.finditer(r'https://history\.state\.gov/historicaldocuments/([^/)]+)/(d\d+)', ov):
    p=(m.group(1),m.group(2))
    if p not in cited: cited.append(p)
coll=json.load(open(RUN+"collection.fruscollection"))
cpairs=[(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"]
print("overview cites", len(cited), "distinct documents; collection holds", len(cpairs))
print("cited but not in collection:", [p for p in cited if p not in cpairs])
print("in collection but not cited in overview:", [p for p in cpairs if p not in cited])
SQL="""SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
 LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
 WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0
 AND (d.date_iso IS NULL OR (d.date_iso>=? AND d.date_iso<=?))"""
# the thirteen expressions of memo section 3, with the memo's date ranges and its counts
Q=[
 ('body_text:corrupt AND body_text:aid', None, None, 914),
 ('body_text:NEAR(corrupt aid, 10)', '1944-01-01','1950-12-31', 5),
 ('body_text:corrupt AND body_text:(China OR Chinese OR Kuomintang)', '1947-06-01','1949-12-31', 120),
 ('body_text:corrupt AND body_text:(Chiang OR Generalissimo)', '1943','1946', 70),
 ('body_text:corrupt AND (Chiang OR Generalissimo OR Nationalist*) AND (aid OR assistance) AND (withdraw* OR terminate* OR cease OR "further aid" OR "white paper")', '1949','1950', 21),
 ('body_text:NEAR(corrupt Diem, 40) OR NEAR(corrupt Vietnam, 30)', '1954','1963', 57),
 ('body_text:corrupt AND (Marcos OR Philippine*)', '1983','1990', 8),
 ('body_text:("questionable payments" OR "illicit payments" OR "foreign corrupt practices" OR "corrupt practices act")', None, None, 30),
 ('body_text:(brib* OR corrupt) AND (Minister OR Legation OR Department)', '1860','1899', 343),
 ('body_text:corrupt AND (loan OR receivership OR customs OR financial) AND (control OR supervision OR reform)', '1900','1925', 92),
 ('body_text:corrupt AND (extraterritorial* OR "consular court*" OR capitulations)', '1860','1935', 30),
 ('body_text:NEAR(corrupt Congress, 25) AND (aid OR assistance)', '1950','1980', 9),
 ('body_text:(corrupt AND (suspend* OR terminat* OR cutoff OR "cut off" OR halt*) AND (aid OR assistance OR loan*))', '1953','1980', 145),
]
FAM='body_text:(corrupt OR brib* OR graft OR embezzl OR kickback OR "questionable payments" OR "illicit payments")'
results={}
def run(expr,dmin,dmax):
    a=dmin or "0000"; b=dmax or "9999"
    try: return set(db.execute(SQL,(expr,a,b)).fetchall())
    except Exception as e: print("  ERROR", expr, e); return set()
for i,(expr,dmin,dmax,memo_n) in enumerate(Q,1):
    s_lit=run(expr,dmin,dmax)
    # a generous reading when the range is bare years
    if dmax and len(dmax)==4: s_gen=run(expr,dmin+"-01-01",dmax+"-12-31")
    else: s_gen=s_lit
    results[i]=(s_lit,s_gen)
    print(f"q{i:2d} literal={len(s_lit):4d} generous={len(s_gen):4d} memo={memo_n:4d} | {expr[:80]} [{dmin}..{dmax}]")
fam=run(FAM,None,None)
ED2=('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
fam={p for p in fam if p[0] not in ED2}
print("family (Ed2 suppressed):", len(fam))
print("\n== STRICT REACH, per cited document ==")
union_lit=set().union(*[r[0] for r in results.values()]); union_gen=set().union(*[r[1] for r in results.values()])
none_lit=[]; none_any=[]
for p in cited:
    hits_lit=[i for i,(a,b) in results.items() if p in a]; hits_gen=[i for i,(a,b) in results.items() if p in b]
    inf=p in fam
    tag = "FULLTEXT" if (hits_lit or inf) else ("FULLTEXT(generous-date only)" if hits_gen else "NO-QUERY")
    if not (hits_lit or inf): none_lit.append(p)
    if not (hits_lit or hits_gen or inf): none_any.append(p)
    print(f"{p[0]}/{p[1]}: family={inf} section3_literal={hits_lit} section3_generous={hits_gen} -> {tag}")
print("\ncited docs returned by no logged query and not in the family set:", none_any)
print("cited docs returned by no literal-date section-3 query and not in the family set:", none_lit)
# per-query membership of d836 specifically, and of d301
for p in [("frus1922v01","d836"),("frus1964-68v05","d301")]:
    print(p, "in family:", p in fam, "in any section-3 query (generous):", [i for i,(a,b) in results.items() if p in b])
# does d836 contain any family word at all? check LIKE on raw text
t=db.execute("SELECT header||' '||COALESCE(dateline,'')||' '||COALESCE(source_note,'')||' '||body_text FROM document_cache WHERE volume_id='frus1922v01' AND document_id='d836'").fetchone()[0]
print("d836 raw-text family words:", re.findall(r'(?i)corrupt\w*|brib\w*|\bgraft\w*|embezzl\w*|kickback\w*|illicit|questionable', t))
print("d836 header:", db.execute("SELECT header, dateline FROM document_cache WHERE volume_id='frus1922v01' AND document_id='d836'").fetchone())
json.dump({"cited":cited,"collection":cpairs}, open(RUN+"refuter/cited_pairs.json","w"))
