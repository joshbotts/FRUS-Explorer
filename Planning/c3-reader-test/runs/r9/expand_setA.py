# expand_setA.py: for each chapter in setA_chapters.tsv, take the section's documentIds from volume_structures
# (the section whose own+descendant documentIds start at first and end at last); 'whole' keeps every non-apparatus
# document; 'fts' keeps only those matching frus_documents MATCH 'recogn*'. Writes setA_pairs.tsv.
import sqlite3,json,sys
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
structs={}; ftshits={}
def alldocs(s):
    r=list(s.get('documentIds',[]))
    for c in s.get('subsections',[]): r+=alldocs(c)
    return r
def find(secs,first,last):
    for s in secs:
        d=alldocs(s)
        if d and d[0]==first and d[-1]==last: return d
        r=find(s.get('subsections',[]),first,last)
        if r: return r
    return None
out=open('setA_pairs.tsv','w'); tot=0
for line in open('setA_chapters.tsv'):
    v,first,last,mode,label=line.rstrip('\n').split('\t')
    if v not in structs:
        structs[v]=json.loads(con.execute("SELECT structure_json FROM volume_structures WHERE volume_id=?",(v,)).fetchone()[0])['sections']
    docs=find(structs[v],first,last)
    if docs is None: print('NOT FOUND',v,first,last); continue
    keep=[]
    for d in docs:
        row=con.execute("SELECT is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        if row is None or row[0] or row[1]: continue
        if mode=='fts':
            if v not in ftshits:
                ftshits[v]=set(r[0] for r in con.execute("SELECT document_id FROM frus_documents WHERE frus_documents MATCH 'recogn*' AND volume_id=?",(v,)))
            if d not in ftshits[v]: continue
        keep.append(d)
    for d in keep: out.write(f"{v}\t{d}\t{mode}\t{label}\n")
    tot+=len(keep); print(v,first,last,mode,len(docs),'->',len(keep),label)
out.close(); print('TOTAL setA pairs',tot)
