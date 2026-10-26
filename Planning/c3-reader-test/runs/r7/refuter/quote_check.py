# Refuter's quotation check: every straight-double-quoted passage in overview.md and every excerpt in the collection,
# normalised (lower-case, [a-z0-9] only), split at ellipsis marks, each segment required in order at increasing offsets
# in header||dateline||source_note||body_text of the EXACT (volume_id, document_id) the overview's citation names.
import re, json, sqlite3, csv, sys
R="/Users/jbotts/frus-analysis/c3/runs/r7/"
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con=sqlite3.connect(DB, uri=True)
csv.field_size_limit(10**9)
def norm(s): return re.sub(r"[^a-z0-9]", "", s.lower())
def segments(q):
    parts=re.split(r"\[\.\.\.\]|\.\.\.|…", q)
    return [norm(p) for p in parts if norm(p)]
cache={}
def surface(v,d):
    if (v,d) not in cache:
        row=con.execute("SELECT header, dateline, source_note, body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        cache[(v,d)] = (norm("".join(x or "" for x in row[:4])), row[4], row[5]) if row else (None,None,None)
    return cache[(v,d)]
def check(q, v, d):
    surf,fm,en=surface(v,d)
    if surf is None: return False, "pair not in document_cache"
    pos=0; segs=segments(q)
    for s in segs:
        i=surf.find(s, pos)
        if i<0: return False, f"segment not found: {s[:60]}"
        pos=i+len(s)
    return True, f"{len(segs)} segment(s) found in order; apparatus fm={fm} en={en}"
o=open(R+"overview.md").read()
# citations: every history.state.gov pair with its character offset
cites=[(m.start(), m.group(1), m.group(2).rstrip(";.,)")) for m in re.finditer(r"https://history\.state\.gov/historicaldocuments/([^/\s)]+)/([^\s),]+)", o)]
quotes=[(m.start(), m.end(), m.group(1)) for m in re.finditer(r'"([^"]+)"', o)]
print(f"overview: {len(quotes)} double-quoted passages, {len(cites)} citation URLs")
# memo trace: quotes.tsv (Q -> pair, text)
qrows=[r for r in csv.DictReader(open(R+"out/quotes.tsv"), delimiter="\t")]
def trace_pair(q):
    hits=[(r["quote_id"], r["volume_id"], r["document_id"]) for r in qrows if q in r["text"]]
    return hits
fab=mis=ok=0
rows=[]
for (a,b,q) in quotes:
    after=[c for c in cites if c[0]>=b]
    if not after: v=d=None
    else: _,v,d=after[0]
    tr=trace_pair(q)
    tr_pairs={(x[1],x[2]) for x in tr}
    if v is None:
        verdict="NO CITATION AFTER QUOTE"; found=False; why=""
    else:
        found,why=check(q,v,d)
        if found:
            verdict="OK"
            if tr_pairs and (v,d) not in tr_pairs: verdict="OK in cited pair BUT memo trace names "+str(tr_pairs)
        else:
            # is it in the memo's traced pair instead?
            alt=[(p,check(q,*p)) for p in tr_pairs]
            if any(r[1][0] for r in alt): verdict="MIS-CITATION: found in "+str([p for p,r in alt if r[0]])+" not in cited "+str((v,d))
            else: verdict="FABRICATION: "+why
    if verdict=="OK" or verdict.startswith("OK in"): ok+=1
    elif verdict.startswith("MIS"): mis+=1
    elif verdict.startswith("FAB"): fab+=1
    rows.append((q, v, d, [x[0] for x in tr], verdict, why))
    print(f"[{verdict}] ({v},{d}) trace={[x[0] for x in tr]} :: {q[:110]}{'…' if len(q)>110 else ''}")
print(f"\nOVERVIEW SUMMARY: {len(quotes)} quotations; ok={ok}; fabrications={fab}; mis-citations={mis}; other={len(quotes)-ok-fab-mis}")
# single-curly-quoted strings (search terms / titles), listed for completeness
sq=re.findall(r"‘([^’]+)’", o)
print(f"\nsingle-curly-quoted strings in overview (terms, not document quotations): {len(sq)}")
for s in sq: print("   ‘"+s+"’")
# collection excerpts
coll=json.load(open(R+"collection.fruscollection"))
ex=[e for e in coll["entries"] if e["kind"]=="excerpt"]
efab=eok=0
for e in ex:
    found,why=check(e["text"], e["volumeId"], e["documentId"])
    if found: eok+=1
    else: efab+=1; print("EXCERPT FAIL", e["volumeId"], e["documentId"], why, e["text"][:100])
print(f"\nCOLLECTION EXCERPTS: {len(ex)} checked; {eok} found in their cited pair; {efab} not")
# exact (byte) substring check too, as the app's own check requires an exact passage
exact=0
for e in ex:
    row=con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(e["volumeId"],e["documentId"])).fetchone()
    if row and e["text"] in row[0]: exact+=1
    else: print("EXCERPT NOT EXACT SUBSTRING OF body_text:", e["volumeId"], e["documentId"])
print(f"exact substrings of body_text: {exact} of {len(ex)}")
json.dump(rows, open(R+"refuter/overview_quote_rows.json","w"), ensure_ascii=False, indent=1)
