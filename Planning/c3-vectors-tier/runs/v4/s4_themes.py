# Theme co-occurrence per decade. Surfaces: FTS5 (porter stems) over header+dateline+source_note+body_text (body includes editors' footnotes).
# Sets: W = working set (cuba_set.tsv); M = body mention set: MATCH 'cuba OR cuban' (any column). Non-apparatus, non-Ed2, dated by document_dates.date_iso.
import sqlite3,collections,sys
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ED2=('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
base={}
for v,d,iso in c.execute("SELECT dc.volume_id,dc.document_id,dd.date_iso FROM document_cache dc JOIN document_dates dd ON dd.volume_id=dc.volume_id AND dd.document_id=dc.document_id WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0 AND dc.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND dd.date_iso IS NOT NULL"):
    base[(v,d)]=iso[:3]+'0s'
def fts(q):
    s="SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH ?"
    return set(c.execute(s,(q,)).fetchall())
W=set(tuple(l.split('\t')[:2]) for l in open('cuba_set.tsv'))
M=fts('cuba OR cuban')
themes=[('security','"national security"'),('strateg','strategic OR strategy'),('defense','defense OR defence'),
('communis','communist OR communism'),('soviet','soviet'),('missile','missile'),
('sugar','sugar'),('reciproc','reciprocity OR reciprocal'),('tariff','tariff'),('invest','investment OR investor'),
('slave','slave OR slavery'),('annex','annexation OR annex'),('monroe','"monroe doctrine"'),('platt','"platt amendment"'),
('insurrect','insurrection OR insurgent'),('stabil','stability OR stable'),('refugee','refugee OR refugees'),('hijack','hijacking OR hijack')]
T={k:fts(q) for k,q in themes}
decs=['1860s','1870s','1880s','1890s','1900s','1910s','1920s','1930s','1940s','1950s','1960s','1970s','1980s']
for name,S in (('W',W),('M',M)):
    tot=collections.Counter(base[k] for k in S if k in base)
    print("SET",name,"dated non-apparatus N by decade:",' '.join("%s=%d"%(d,tot[d]) for d in decs))
    print("term\t"+'\t'.join(decs))
    for k,q in themes:
        cnt=collections.Counter(base[x] for x in (S & T[k]) if x in base)
        print(k+'\t'+'\t'.join("%d/%d"%(cnt[d],tot[d]) for d in decs))
# 1870s body-mention set rate per 1000
den=collections.Counter(base.values()); m=collections.Counter(base[k] for k in M if k in base)
print("M per1000:",' '.join("%s=%.1f(%d of %d)"%(d,1000*m[d]/den[d],m[d],den[d]) for d in decs))
print("controls: Department of State docs",len(fts('"department of state"')),"; ZZZ_IMPOSSIBLE_ZZZ",len(fts('ZZZ_IMPOSSIBLE_ZZZ')))
