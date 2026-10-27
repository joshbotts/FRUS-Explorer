# Refuter: the headline numbers, independently. Scope set W rebuilt from the memo's rule (M-05), not read from cuba_set.tsv.
import sqlite3, json, re, collections
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c=sqlite3.connect(DB, uri=True)
# Rule A: editors' headings matching /cuba/i at any depth (title field), documents under them
A=set()
def walk(node, vol, inside):
    if isinstance(node, dict):
        title=node.get('title') or ''
        hit = inside or bool(re.search(r'cuba', title, re.I))
        if hit:
            for d in node.get('documentIds') or []: A.add((vol,d))
        for key in ('subsections','sections'):
            for s in node.get(key) or []: walk(s, vol, hit)
    elif isinstance(node, list):
        for x in node: walk(x, vol, inside)
nvol=0
for vol, js in c.execute("SELECT volume_id, structure_json FROM volume_structures"):
    nvol+=1; walk(json.loads(js), vol, False)
B=set(c.execute("SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH 'header:(cuba OR cuban)'").fetchall())
meta={ (v,d):(fm,en) for v,d,fm,en in c.execute("SELECT volume_id, document_id, is_front_matter, is_editorial_note FROM document_cache")}
ED2={'frus1951-54IranEd2','frus1969-76ve15p2Ed2'}
U=A|B
W=sorted(k for k in U if k in meta and meta[k]==(0,0) and k[0] not in ED2)
print("volume_structures rows:", nvol, "| A (heading rule) =", len(A), "| B (header FTS) =", len(B), "| union =", len(U), "| W kept =", len(W))
Wset=set(W)
sess=set(tuple(l.rstrip('\n').split('\t')[:2]) for l in open('/Users/jbotts/frus-analysis/c3v/runs/v4/cuba_set.tsv'))
print("session cuba_set.tsv:", len(sess), "| symmetric difference with my W:", len(Wset ^ sess))
dates={(v,d):iso for v,d,iso in c.execute("SELECT volume_id, document_id, date_iso FROM document_dates")}
ds=sorted(dates[k] for k in W if dates.get(k))
print("W dated:", len(ds), "undated:", len(W)-len(ds), "| span", ds[0], "to", ds[-1], "| volumes in W:", len(set(v for v,_ in W)))
# Headline 3: documents with a source (document_sources row) vs documents with a non-empty source_note
srcrows=set(c.execute("SELECT volume_id, document_id FROM document_sources").fetchall())
print("W with a document_sources row:", len(Wset & srcrows))
sn=set(c.execute("SELECT volume_id, document_id FROM document_cache WHERE source_note IS NOT NULL AND trim(source_note)<>''").fetchall())
print("W with a non-empty source_note text:", len(Wset & sn), "| with text but no document_sources row:", len((Wset & sn) - srcrows), "| with row but empty text:", len((Wset & srcrows) - sn))
# Headline 4: pointed-at (external_citations) documents and rows, and the earliest
ec=collections.Counter(); 
for v,d in c.execute("SELECT volume_id, document_id FROM external_citations"):
    if (v,d) in Wset: ec[(v,d)]+=1
print("W documents with external_citations rows:", len(ec), "| rows:", sum(ec.values()))
mind=min((dates.get(k) or '9999', k) for k in ec)
print("earliest W document with an external citation:", mind)
# lots pointed at (most-cited lot)
pl=collections.Counter()
for v,d,lot in c.execute("SELECT volume_id, document_id, lot_file_norm FROM external_citations WHERE lot_file_norm IS NOT NULL"):
    if (v,d) in Wset: pl[lot]+=1
print("pointed-at lots, top 6 (rows):", pl.most_common(6))
pld=collections.defaultdict(set)
for v,d,lot in c.execute("SELECT volume_id, document_id, lot_file_norm FROM external_citations WHERE lot_file_norm IS NOT NULL"):
    if (v,d) in Wset: pld[lot].add((v,d))
print("pointed-at lots, top 6 (documents):", sorted(((len(s),l) for l,s in pld.items()), reverse=True)[:6])
# Headline 5: "national security" FTS hits within W
H=set(c.execute("SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH '\"national security\"'").fetchall())
HW=H & Wset
print('"national security" FTS hits in W:', len(HW))
# the 47: body_text with institution/file names deleted
SEP=r'[\s\-,().]+'
inst=re.compile(r'\bnational'+SEP+r'securit(?:y|ies)'+SEP+r'(?:files?|council|action|advis[eo]r|affairs|agency|archives?|memorand\w*|stud\w*|decision\w*|staff|policy papers?|documents?)\b', re.I)
tol=re.compile(r'\bnational'+SEP+r'securit(?:y|ies)\b', re.I)
own=collections.Counter(); tot=0
for v,d in HW:
    body=' '.join(c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0].split())
    if tol.search(inst.sub(' ', body)):
        tot+=1; own[(dates.get((v,d)) or '????')[:3]+'0s']+=1
print('"national security" surviving the institution-name deletion:', tot, dict(sorted(own.items())))
# prosperity: W literal per decade, and the 1865-1889 second set (M19) per decade
pros=re.compile(r'\bprosper\w*', re.I)
pw=collections.Counter()
for v,d in W:
    iso=dates.get((v,d))
    if not iso: continue
    body=' '.join(c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0].split())
    if pros.search(body): pw[iso[:3]+'0s']+=1
print("prosper* in W by decade:", dict(sorted(pw.items())))
cuba2=re.compile(r'\bCuba(?:n|ns)?\b')
n19=collections.Counter(); p19=collections.Counter()
for v,d,iso,b in c.execute("SELECT dc.volume_id, dc.document_id, dd.date_iso, dc.body_text FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=dc.volume_id AND dd.document_id=dc.document_id WHERE frus_documents MATCH 'cuba OR cuban' AND dc.is_front_matter=0 AND dc.is_editorial_note=0 AND dd.date_iso BETWEEN '1865' AND '1890'"):
    b=' '.join(b.split())
    if len(cuba2.findall(b))<2: continue
    dec=iso[:3]+'0s'; n19[dec]+=1
    if pros.search(b): p19[dec]+=1
print("second set (M19) N by decade:", dict(sorted(n19.items())), "total", sum(n19.values()), "| prosper* in it:", dict(sorted(p19.items())))
# unresolved lots: 70D149 and 65D533 in central-files-index?
cf=json.load(open('/Applications/FRUS Explorer.app/Contents/Resources/central-files-index.json'))
lots={r['lotNumber'] for r in cf['lotFiles']}
cited_lots=set(l for l in pl)
unres=sorted(l for l in cited_lots if l not in lots)
print("pointed-at lots in W not in central-files-index lotFiles:", len(unres), unres)
# M-07 decade table check for the 1960s and the 1870s
den=collections.Counter(); num=collections.Counter(); top=collections.defaultdict(collections.Counter)
for k,(fm,en) in meta.items():
    if fm or en or k[0] in ED2: continue
    iso=dates.get(k)
    if iso: den[iso[:3]+'0s']+=1
for k in W:
    iso=dates.get(k)
    if iso: num[iso[:3]+'0s']+=1; top[iso[:3]+'0s'][k[0]]+=1
for dec in ['1870s','1890s','1940s','1960s','1980s']:
    print(dec, "W", num[dec], "of", den[dec], "per 1000 %.1f"%(1000*num[dec]/den[dec]), "top", top[dec].most_common(1))
M=set(c.execute("SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH 'cuba OR cuban'").fetchall())
mm=collections.Counter()
for k in M:
    if k in meta and meta[k]==(0,0) and k[0] not in ED2 and dates.get(k): mm[dates[k][:3]+'0s']+=1
for dec in ['1860s','1870s','1880s','1890s','1940s','1960s','1970s','1980s']:
    print("mention set", dec, mm[dec], "of", den[dec], "per 1000 %.1f"%(1000*mm[dec]/den[dec]))
print("mention set M size (all rows):", len(M))
json.dump({'W':W}, open('refuter_W.json','w'))
