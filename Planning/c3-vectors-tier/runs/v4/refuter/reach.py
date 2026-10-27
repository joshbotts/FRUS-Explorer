# Refuter: for each of the 16 cited pairs, which logged full-text / heading query returns it.
import re, json, sqlite3
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c=sqlite3.connect(DB, uri=True)
cited=[('frus1870','d197'),('frus1873p1v2','d50'),('frus1874','d552'),('frus1898','d490'),('frus1898','ch83'),('frus1902','d294'),('frus1933v05','d241'),('frus1934v05','d170'),('frus1945v09','d745'),('frus1958-60v06','d517'),('frus1958-60v06','d567'),('frus1961-63v10','d202'),('frus1961-63v11','d34'),('frus1969-76ve11p1','d278'),('frus1977-80v23','d19'),('frus1977-80v23','d98')]
log=open('/Users/jbotts/frus-analysis/c3v/runs/v4/queries.log', encoding='utf-8').read().split('\n')
ranked=[]
for line in log:
    if line.startswith('sqlite3') and ('MATCH' in line or 'LIKE' in line) and line.rstrip().endswith('"'):
        sql=line[line.index('" "')+3:-1] if '" "' in line else None
        if sql is None:
            m=re.search(r'mode=ro" "(.*)"$', line.rstrip())
            sql=m.group(1) if m else None
        if sql and sql.lstrip().upper().startswith('SELECT DC.'): ranked.append(sql)
print("ranked retrieval queries parsed from queries.log:", len(ranked))
hits={p:[] for p in cited}
for n,sql in enumerate(ranked,1):
    try:
        rows=c.execute(sql).fetchall()
    except Exception as e:
        print("  Q%d FAILED: %s | %s"%(n,e,sql[:120])); continue
    pairs=set((r[0],r[1]) for r in rows)
    print("  Q%d rows=%d | %s"%(n,len(rows),re.search(r"MATCH '([^']*)'|LIKE", sql).group(0)[:110]))
    for p in cited:
        if p in pairs: hits[p].append('Q%d'%n)
W=set(tuple(x) for x in json.load(open('refuter_W.json'))['W'])
# heading rule alone (rule A) and header FTS alone (rule B)
A=set()
def walk(node, vol, inside):
    if isinstance(node, dict):
        t=node.get('title') or ''; hit=inside or bool(re.search(r'cuba', t, re.I))
        if hit:
            for d in node.get('documentIds') or []: A.add((vol,d))
        for key in ('subsections','sections'):
            for s in node.get(key) or []: walk(s, vol, hit)
for vol, js in c.execute("SELECT volume_id, structure_json FROM volume_structures"): walk(json.loads(js), vol, False)
B=set(c.execute("SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH 'header:(cuba OR cuban)'").fetchall())
M=set(c.execute("SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH 'cuba OR cuban'").fetchall())
NS=set(c.execute("SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH '\"national security\"'").fetchall())
DOS=set(c.execute("SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH '\"department of state\"'").fetchall())
M19=set()
cuba2=re.compile(r'\bCuba(?:n|ns)?\b')
for v,d,iso,b in c.execute("SELECT dc.volume_id, dc.document_id, dd.date_iso, dc.body_text FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=dc.volume_id AND dd.document_id=dc.document_id WHERE frus_documents MATCH 'cuba OR cuban' AND dc.is_front_matter=0 AND dc.is_editorial_note=0 AND dd.date_iso BETWEEN '1865' AND '1890'"):
    if len(cuba2.findall(' '.join(b.split())))>=2: M19.add((v,d))
# the session's theme FTS queries (s4) are census queries too; list membership in a few
print("\nper cited pair: ranked queries | scope set W | heading rule A | header FTS B | census M ('cuba OR cuban') | M19 (1865-89) | 'national security' | 'department of state'")
for p in cited:
    print("  %s/%s: %s | W=%s | A=%s | B=%s | M=%s | M19=%s | NS=%s | DOS=%s"%(p[0],p[1],','.join(hits[p]) or '-', p in W, p in A, p in B, p in M, p in M19, p in NS, p in DOS))
strict_fts=[p for p in cited if hits[p] or p in W or p in M or p in M19 or p in NS or p in DOS]
retrieval_fts=[p for p in cited if hits[p] or p in W]
print("\nSTRICT (any logged MATCH/heading query or the scope set, census queries included): reached", len(strict_fts), "of", len(cited))
print("RETRIEVAL-ONLY (ranked LIMIT queries + scope set W/heading walk): reached", len(retrieval_fts), "of", len(cited), "| not reached:", [p for p in cited if p not in retrieval_fts])
