# analysis.py: controls, false-friend test, census regexes, decade table. All reads READ-ONLY. Output -> analysis_out.txt
import sqlite3,re,collections,sys
out=open('/Users/jbotts/frus-analysis/c3/runs/r5/analysis_out.txt','w')
def P(*a):
    s=' '.join(str(x) for x in a); print(s); out.write(s+'\n'); out.flush()
c=sqlite3.connect('file:/Users/jbotts/frus-analysis/c3/runs/r5/scope.db?mode=ro',uri=True)
c.execute("attach database 'file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro' as m")
# 1. controls (index, FTS) on a plain read-only connection
cm=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
q1="SELECT count(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '\"department of state\"' AND d.is_front_matter=0 AND d.is_editorial_note=0"
q2="SELECT count(*) FROM frus_documents WHERE frus_documents MATCH '\"ZZZ_IMPOSSIBLE_ZZZ\"'"
P("SQL1:",q1); P("positive control: volumes (of 553) with >=1 non-apparatus doc matching \"department of state\":",cm.execute(q1).fetchone()[0])
P("SQL2:",q2); P("negative control rows:",cm.execute(q2).fetchone()[0])
qv="SELECT count(DISTINCT volume_id) FROM document_cache"
P("SQL:",qv,cm.execute(qv).fetchone()[0])
# 2. load scope volumes' docs
scope=set(c.execute("select volume_id,document_id from scope").fetchall())
vols=sorted({v for v,d in scope})
RX={'recogni':re.compile(r'recogni',re.I),'de facto':re.compile(r'de facto',re.I),'Department of State (control)':re.compile(r'Department of State',re.I),'ZZZ_IMPOSSIBLE_ZZZ (neg control)':re.compile(r'ZZZ_IMPOSSIBLE_ZZZ',re.I)}
cnt={k:[0,0] for k in RX}; ncnt={k:[0,0] for k in RX}; nsc=0;nns=0
for v in vols:
    for d,h,dl,sn,b in c.execute("select document_id,header,dateline,source_note,body_text from m.document_cache where volume_id=? and is_front_matter=0 and is_editorial_note=0",(v,)):
        t=' '.join(' '.join([h or '',dl or '',sn or '',b]).split())
        ins=(v,d) in scope
        if ins: nsc+=1
        else: nns+=1
        for k,r in RX.items():
            hit=1 if r.search(t) else 0
            if ins: cnt[k][0]+=hit
            else: ncnt[k][0]+=hit
P("FALSE-FRIEND TEST (regex, case-insensitive, over header+dateline+source_note+body collapsed; 38 scope volumes):")
for k in RX:
    P(f"  {k}: scope docs {cnt[k][0]} of {nsc}; other non-apparatus docs of the same 38 volumes {ncnt[k][0]} of {nns}")
# 3. census regexes over scope docs, strict and tolerant
sep=r'[\s\-,\(\)\.]+'
FAM={
 'de facto':(r'de facto', r'de'+sep+r'facto'),
 'free election(s)':(r'free elections?', r'free'+sep+r'elections?'),
 'constitutional government/order':(r'constitutional (government|order|methods|procedures|processes)', r'constitution(al)?'+sep+r'(government|order|methods|procedures|processes)'),
 'international obligations':(r'international obligations?', r'international'+sep+r'obligations?'),
 'recognition (recogni*)':(r'recogni', r'recogni'),
 'civil liberties':(r'civil liberties', r'civil'+sep+r'liberties'),
 'consult(ation) with other governments':(r'consultation', r'consult'),
}
S={k:[0,0] for k in FAM}; n=0
for v in vols:
    for d,h,dl,sn,b in c.execute("select document_id,header,dateline,source_note,body_text from m.document_cache where volume_id=? and is_front_matter=0 and is_editorial_note=0",(v,)):
        if (v,d) not in scope: continue
        n+=1
        t=' '.join(' '.join([h or '',dl or '',sn or '',b]).split())
        for k,(st,tol) in FAM.items():
            if re.search(st,t,re.I): S[k][0]+=1
            if re.search(tol,t,re.I): S[k][1]+=1
P("CENSUS over all scope docs (regex, case-insensitive): STRICT = single spaces; TOLERANT = any run of space/hyphen/comma/paren/full stop between words")
for k,(a,b) in S.items(): P(f"  {k}: STRICT {a} of {n}; TOLERANT {b} of {n}")
# 4. decade table
P("DECADE TABLE (document_dates.date_iso; non-apparatus docs):")
allc=collections.Counter(); scc=collections.Counter(); topv=collections.defaultdict(collections.Counter)
for v,d,di in c.execute("select dd.volume_id,dd.document_id,dd.date_iso from m.document_dates dd join m.document_cache dc on dc.volume_id=dd.volume_id and dc.document_id=dd.document_id where dc.is_front_matter=0 and dc.is_editorial_note=0 and dd.date_iso is not null"):
    dec=int(di[:4])//10*10; allc[dec]+=1
    if (v,d) in scope: scc[dec]+=1; topv[dec][v]+=1
nodate=sum(1 for (v,d) in scope)-sum(scc.values())
for dec in sorted(scc):
    tv,tn=topv[dec].most_common(1)[0]
    P(f"  {dec}s: scope {scc[dec]} of {allc[dec]} dated non-apparatus docs = {1000*scc[dec]/allc[dec]:.1f} per 1,000; top volume {tv} holds {tn} of {scc[dec]} ({100*tn/scc[dec]:.0f}%)")
P("  scope docs without a date_iso:",nodate)
