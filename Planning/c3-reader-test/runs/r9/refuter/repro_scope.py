# refuter: re-derive the scope from the session's inputs (setA_chapters.tsv, setB_relevant.txt, lavols.txt) against the index,
# and recount the headline numbers independently of scope_pairs.tsv. Writes only into refuter/.
import sqlite3, json, re, collections, os
R='/Users/jbotts/frus-analysis/c3/runs/r9'; OUT=R+'/refuter'
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
# ---- Set A: chapters -> documents via volume_structures (+ FTS 'recogn*' for fts-mode chapters)
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
chapters=[l.rstrip('\n').split('\t') for l in open(R+'/setA_chapters.tsv') if l.strip()]
print('setA_chapters rows:',len(chapters),'distinct (vol,first,last):',len({(c[0],c[1],c[2]) for c in chapters}))
structs={}; fts={}; A=collections.OrderedDict(); notfound=0; whole_n=fts_n=0; whole_ch=fts_ch=0; fts_cands=0
for v,first,last,mode,label in chapters:
    if v not in structs:
        structs[v]=json.loads(con.execute("SELECT structure_json FROM volume_structures WHERE volume_id=?",(v,)).fetchone()[0])['sections']
    docs=find(structs[v],first,last)
    if docs is None: notfound+=1; print('NOT FOUND',v,first,last); continue
    if mode=='fts':
        fts_ch+=1
        if v not in fts: fts[v]=set(r[0] for r in con.execute("SELECT document_id FROM frus_documents WHERE frus_documents MATCH 'recogn*' AND volume_id=?",(v,)))
    else: whole_ch+=1
    for d in docs:
        row=con.execute("SELECT is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        if row is None or row[0] or row[1]: continue
        if mode=='fts':
            fts_cands+=1
            if d not in fts[v]: continue
            fts_n+=1
        else: whole_n+=1
        A[(v,d)]=mode
print(f'Set A: {len(A)} pairs; chapters not found {notfound}; whole-mode chapters {whole_ch} -> {whole_n} docs; fts-mode chapters {fts_ch} -> {fts_n} of {fts_cands} non-apparatus chapter docs')
# ---- Set B: NEAR query over the 49 LA volumes, >= frus1950, non-apparatus
la=[l.strip() for l in open(R+'/lavols.txt') if l.strip()]
print('lavols.txt volumes:',len(la))
q=open(R+'/setB_query.txt').read().strip()
ph=','.join('?'*len(la))
rows=con.execute(f"SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id IN ({ph}) AND f.volume_id >= 'frus1950' ORDER BY f.volume_id, f.document_id",[q]+la).fetchall()
Bhits=set(rows)
print('Set B hits:',len(Bhits),'in',len({v for v,d in Bhits}),'volumes')
# controls
n_ds=con.execute(f"SELECT COUNT(*) FROM frus_documents f WHERE frus_documents MATCH '\"Department of State\"' AND f.volume_id IN ({ph})",la).fetchone()[0]
n_dsv=con.execute(f"SELECT COUNT(DISTINCT volume_id) FROM frus_documents WHERE frus_documents MATCH '\"Department of State\"' AND volume_id IN ({ph})",la).fetchone()[0]
n_zz=con.execute(f"SELECT COUNT(*) FROM frus_documents f WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ' AND f.volume_id IN ({ph})",la).fetchone()[0]
print('controls: "Department of State"',n_ds,'docs in',n_dsv,'vols; ZZZ',n_zz)
# compare with the session's setB_hits.tsv
sess_hits=set(tuple(l.strip().split('|')) for l in open(R+'/setB_hits.tsv') if l.strip())
print('session setB_hits.tsv:',len(sess_hits),'same set as my re-run:',sess_hits==Bhits)
# relevant
rel=set()
for l in open(R+'/setB_relevant.txt'):
    p=l.split()
    if p: rel.update((p[0],d) for d in p[1:])
print('setB_relevant.txt pairs:',len(rel),'all within hits:',rel<=Bhits,'not in hits:',sorted(rel-Bhits)[:5])
B=rel&Bhits
# ---- union
scope=collections.OrderedDict()
for k in A: scope[k]='A'
for k in B: scope[k]=scope.get(k,'')+'B'
vols=sorted({v for v,d in scope})
print(f'SCOPE union {len(scope)} docs in {len(vols)} volumes; A-only {sum(1 for c in scope.values() if c=="A")}, B-only {sum(1 for c in scope.values() if c=="B")}, both {sum(1 for c in scope.values() if c=="AB")}')
print('overlap pairs:',[k for k,c in scope.items() if c=='AB'])
sess=set(tuple(l.split('\t')[:2]) for l in open(R+'/scope_pairs.tsv') if l.strip())
print('session scope_pairs.tsv:',len(sess),'same set:',sess==set(scope))
# date span
dates=[]; undated=0
for v,d in scope:
    r=con.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if r and r[0]: dates.append((r[0],v,d))
    else: undated+=1
dates.sort()
print('date span: earliest',dates[0],'latest',dates[-1],'undated',undated)
dec=collections.Counter(x[0][:3]+'0s' for x in dates)
print('by decade:',dict(sorted(dec.items())))
# per-volume counts
pv=collections.Counter(v for v,d in scope)
with open(OUT+'/scope_volumes.tsv','w') as f:
    for v in vols: f.write(f'{v}\t{pv[v]}\n')
print('volumes:',', '.join(vols))
# ---- came-from
repo=collections.Counter(); rows_n=0; missing=0; suffix=collections.Counter(); parsable=0; era=collections.Counter()
for v,d in scope:
    r=con.execute("SELECT repository, record_group, series_name, citation_era FROM document_sources WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: missing+=1; continue
    rows_n+=1; repo[(r[0] or '-', r[1] or '-')]+=1; era[r[3]]+=1
    if r[3]=='decimal' and r[2]:
        m=re.match(r'(\d{3})\.(\d{2,4})',r[2])
        if m: parsable+=1; suffix['.'+m.group(2)[:2]]+=1
print(f'CAME-FROM rows {rows_n}, scope docs with no row {missing}')
print('by repository/RG:',repo.most_common(10))
print('citation_era:',dict(era))
print(f'decimal parsable {parsable}; .00 {suffix[".00"]}; .01 {suffix[".01"]}; share .01 = {suffix[".01"]/parsable:.3f}')
# ---- pointed-at
pa=collections.Counter(); pa_rows=0; pa_docs=0
for v,d in scope:
    rr=con.execute("SELECT repository, collection, lot_file_norm, decimal_class FROM external_citations WHERE volume_id=? AND document_id=?",(v,d)).fetchall()
    if rr: pa_docs+=1
    for r in rr: pa_rows+=1; pa[(r[0] or '-',(r[1] or '-')[:50],r[2] or '-',r[3] or '-')]+=1
print(f'POINTED-AT rows {pa_rows} in {pa_docs} docs; top:',pa.most_common(16))
json.dump({'scope':[list(k)+[c] for k,c in scope.items()]},open(OUT+'/scope_repro.json','w'))
