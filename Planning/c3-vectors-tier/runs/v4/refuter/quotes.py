# Refuter: every quotation in overview.md and every excerpt in the collection, checked by the guide's rule
# against header||dateline||source_note||body_text of the EXACT cited pair.
import re, json, sqlite3
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c=sqlite3.connect(DB, uri=True)
def norm(s): return re.sub(r'[^a-z0-9]', '', s.lower())
def segments(q):
    parts=re.split(r'…|\.\.\.|\[\.\.\.\]', q)
    return [norm(p) for p in parts if norm(p)]
cache={}
def doctext(v,d):
    if (v,d) not in cache:
        r=c.execute("SELECT header, dateline, source_note, body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        cache[(v,d)]=None if r is None else (norm(' '.join(x or '' for x in r[:4])), r[4], r[5])
    return cache[(v,d)]
def check(q, v, d):
    t=doctext(v,d)
    if t is None: return ('NO-SUCH-PAIR', [])
    text=t[0]; pos=0; offs=[]
    for seg in segments(q):
        i=text.find(seg, pos)
        if i<0: return ('NOT-FOUND', offs+[(seg[:40], -1)])
        offs.append((seg[:40], i)); pos=i+len(seg)
    return ('FOUND', offs)
ov=open('/Users/jbotts/frus-analysis/c3v/runs/v4/overview.md', encoding='utf-8').read()
paras=ov.split('\n')
urlre=re.compile(r'historicaldocuments/([A-Za-z0-9\-]+)/([A-Za-z0-9]+)')
results=[]
n=0
for li,line in enumerate(paras):
    for m in re.finditer(r'"([^"]+)"', line):
        q=m.group(1); n+=1
        after=line[m.end():]
        u=urlre.search(after)
        if u:
            v,d=u.group(1),u.group(2)
            st,offs=check(q,v,d)
            results.append((n,li+1,q,v,d,st,offs))
        else:
            results.append((n,li+1,q,None,None,'UNATTRIBUTED-TERM',[]))
print("OVERVIEW: %d spans inside straight double quotes"%n)
att=[r for r in results if r[3]]
print("  attributed to a document (a URL follows in the same line): %d"%len(att))
for r in att:
    print("  #%d line %d %s/%s %s | %s"%(r[0],r[1],r[3],r[4],r[5],r[2][:70]))
    if r[5]!='FOUND': print("      offsets:", r[6])
print("  unattributed terms/names (no document; not a document quotation): %d"%(len(results)-len(att)))
for r in results:
    if not r[3]: print("    #%d line %d: \"%s\""%(r[0],r[1],r[2]))
# block quotes?
bq=[l for l in paras if l.startswith('>')]
print("OVERVIEW block quotes ('>' lines):", len(bq))
# collection excerpts
col=json.load(open('/Users/jbotts/frus-analysis/c3v/runs/v4/collection.fruscollection', encoding='utf-8'))
ex=[e for e in col['entries'] if e['kind']=='excerpt']
print("\nCOLLECTION: %d excerpts"%len(ex))
for k,e in enumerate(ex,1):
    st,offs=check(e['text'], e['volumeId'], e['documentId'])
    fm=doctext(e['volumeId'],e['documentId'])
    print("  E%d %s/%s %s fm/en=%s/%s | %s"%(k,e['volumeId'],e['documentId'],st,fm[1],fm[2],e['text'][:70]))
    if st!='FOUND': print("      offsets:", offs)
# are overview quotations each inside a collection excerpt of the same pair?
exmap={}
for e in ex: exmap.setdefault((e['volumeId'],e['documentId']),[]).append(norm(e['text']))
print("\nOVERVIEW quotation vs collection excerpt of the same pair:")
for r in att:
    inside=any(norm(r[2]) in x for x in exmap.get((r[3],r[4]),[]))
    print("  #%d %s/%s inside-an-excerpt=%s"%(r[0],r[3],r[4],inside))
# also the memo's M-22..M-39 passages, as the trace gives them
memo=open('/Users/jbotts/frus-analysis/c3v/runs/v4/memo.md', encoding='utf-8').read()
mm=re.findall(r'^(M-\d\d) (frus[^/\s]+)/(\S+?)(?: \([^)]*\))?: "(.+)"\s*$', memo, re.M)
print("\nMEMO M-22..M-39 passages found by regex:", len(mm))
for tag,v,d,q in mm:
    st,offs=check(q,v,d)
    print("  %s %s/%s %s | %s"%(tag,v,d,st,q[:60]))
