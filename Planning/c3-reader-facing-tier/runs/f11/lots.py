import sqlite3,json,collections
exec(open("arch.py").read().split("def came")[0])
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf={r["lotNumber"]:r for r in json.load(open(R+"central-files-index.json"))["lotFiles"]}
sf=json.load(open(R+"series-facts-index.json")); H=sf["headings"]
def fact(naid):
    v=sf["byNaId"].get(str(naid))
    if not v: return None
    return {"creator":H[v["c"]] if "c" in v else None,"extent":v.get("x"),"years":"%s-%s"%(v.get("y0"),v.get("y1")),"access":sf["statuses"][v["as"]] if "as" in v else None}
def lots(S,col,table,label):
    c=collections.Counter(); docs=collections.defaultdict(set)
    for v,d in S:
        for (l,) in db.execute("select %s from %s where volume_id=? and document_id=? and %s is not null"%(col,table,col),(v,d)):
            c[l]+=1; docs[l].add((v,d))
    print("\n%s: distinct lots %d"%(label,len(c)))
    for l,n in c.most_common(14):
        r=cf.get(l); 
        print("  lot %-10s docs %3d | central-files-index: %s | facts: %s"%(l,len(docs[l]),(r["recordGroup"]+" NAID "+r["naId"]+" "+r["title"][:60]) if r else "NOT IN INDEX",fact(r["naId"]) if r and r.get("naId") else None))
lots(setA,"lot_file_norm","document_sources","CAME-FROM (document_sources.lot_file_norm), Set A")
lots(setB,"lot_file_norm","document_sources","CAME-FROM (document_sources.lot_file_norm), Set B")
lots(setB,"lot_file_norm","external_citations","POINTED-AT (external_citations.lot_file_norm), Set B")
