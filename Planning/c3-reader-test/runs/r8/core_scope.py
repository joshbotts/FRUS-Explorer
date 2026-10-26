import sqlite3,json,re,collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
la=[l.split("\t")[0] for l in open("la_volumes.tsv")]
country=re.compile(r"Mexico|Guatemala|Honduras|Salvador|Nicaragua|Costa Rica|Panama|Cuba|Haiti|Dominican|Santo Domingo|Colombia|Venezuela|Ecuador|Peru|Bolivia|Chile|Argentin|Brazil|Paraguay|Uruguay|Central America|American Republics",re.I)
topic=re.compile(r"recogni[sz]|revolution|coup|junta|overthrow|de facto|insurrection|usurp|regime|dictator|Tinoco|Huerta|Obreg|Mart[ií]nez|Farrell|Ram[ií]rez",re.I)
excl=re.compile(r"meat|ship measurement|load line|airworth|claims|consul|naturaliz|blockade|Monroe Doctrine|taxation|customs|asylum during|protection of American|neutrality|oil interests|frontier|incursion|bands|revolutionists in|aid to revolutionists|conspiracy|Spain >|military cooperation",re.I)
rows=[]; chapters=[]
def walk(vid,sec,path):
    t=" ".join((sec.get("title") or "").split())
    p=path+[t] if t else path
    full=" > ".join(p)
    ids=sec.get("documentIds",[])
    if ids and country.search(full) and topic.search(full) and not excl.search(full):
        chapters.append((vid,full,len(ids)))
        for d in ids: rows.append((vid,d,full))
    for s in sec.get("subsections",[]): walk(vid,s,p)
for vid,sj in db.execute("SELECT volume_id, structure_json FROM volume_structures WHERE volume_id IN (%s)"%",".join("'%s'"%v for v in la)):
    for s in json.loads(sj).get("sections",[]): walk(vid,s,[])
with open("core_chapters_auto.tsv","w") as f:
    for c in chapters: f.write("\t".join([c[0],c[1],str(c[2])])+"\n")
print(len(chapters),"chapters,",len(rows),"document slots")
for c in chapters: print(c[0],"|",c[1][:140],"|",c[2])
