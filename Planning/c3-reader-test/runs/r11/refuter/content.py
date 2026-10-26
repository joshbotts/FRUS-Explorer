import sqlite3,re
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
def ctx(v,d,pat,w=260,n=3):
    r=con.execute("SELECT header||' '||coalesce(dateline,'')||' '||coalesce(source_note,'')||' '||body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    t=re.sub(r'\s+',' ',r)
    ms=list(re.finditer(pat,t,re.I))
    print("## %s/%s  /%s/  hits=%d"%(v,d,pat,len(ms)))
    for m in ms[:n]: print("   ...",t[max(0,m.start()-w):m.end()+w],"...")
    if not ms: print("   (no hit)")
# Finding 1
ctx("frus1868p2","d632",r"Colombia|Bogot|Acosta|acquiescence",200,4)
ctx("frus1868p2","d598",r"Venezuela|Caracas|provisional|recogni",200,4)
ctx("frus1899","d805",r"Castro|recogni|formal",200,4)
# Finding 2
ctx("frus1913","d7",r"March 11|circular|Latin America|statement",150,4)
ctx("frus1917","d379",r"Tinoco|Costa Rica",150,3)
ctx("frus1923v02","d345",r"relatives|blood|fourth degree|Article II|Hughes|adhere|publish",220,6)
ctx("frus1932v05","d618",r"exception|Treaty|designate",200,4)
# Finding 3
ctx("frus1921v02","d344",r"treaty|property|1917|Constitution|Obreg",200,6)
ctx("frus1930v01","d375",r"exception|Central America|treaty|Cuba|Haiti|Panama|Dominican",220,6)
# Finding 4
ctx("frus1934v05","d220",r"Nicaragua|Mart[ií]nez|plan|propos",200,4)
ctx("frus1936v05","d112",r"confidential|enclos|memorand|should no longer be guided",220,6)
# Finding 5
ctx("frus1943v05","d33",r"recommend|resolution|Committee",200,4)
ctx("frus1944v07","d428",r"recogni|not connected|no connection|consult",220,6)
ctx("frus1946v11","d773",r"election|consensus|concert|other republics|recogni",200,6)
# Finding 6
ctx("frus1948v09","d7",r"Not printed|1947|study|RE ",200,6)
ctx("frus1948v09","d119",r"Bogot|Res 35|Resolution 35|domestic|judgment",200,5)
ctx("frus1949v02","d454",r"Bogot|judgment|Resolution",200,4)
ctx("frus1961-63v12","d421",r"suspend",200,4)
ctx("frus1961-63v12","d359",r"triumvirate|Triumvirate",200,3)
ctx("frus1964-68v31","d132",r"consult|Rio|Resolution XXVI|1965",220,6)
ctx("frus1964-68v31","d512",r"doctrine|Estrada|textbook",200,4)
ctx("frus1969-76v21","d361",r"Porter|24|Monday|established fact|announce",220,8)
