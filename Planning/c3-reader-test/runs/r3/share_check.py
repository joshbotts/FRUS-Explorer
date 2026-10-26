# Literal-share check (house rule a). Surface: header+dateline+source_note+body_text concatenated, whitespace-collapsed (index text, not TEI).
import sqlite3,re,json
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c=sqlite3.connect(DB,uri=True)
ontopic=open('onTopicVolumes.txt').read().split('\n')
ED2=('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
def hits(match,restrict):
    q="SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (?,?)"
    r=c.execute(q,(match,)+ED2).fetchall()
    if restrict: r=[x for x in r if x[0] in set(ontopic)]
    return sorted(r)
def text(v,d):
    h,dl,sn,b=c.execute("select header,coalesce(dateline,''),coalesce(source_note,''),body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    return re.sub(r'\s+',' ',' '.join([h,dl,sn,b]))
def sample(lst,n=40):
    N=len(lst); return [lst[int(i*N/n)] for i in range(n)]
tests={
 'recogni*':(r'recogni',r'recogni'),   # one prefix: strict = tolerant
 'department of state':(r'department of state', r'departments?[\s,\-\(\)\.]+of[\s,\-\(\)\.]+states?'),
}
res={}
for label,match,restrict in [('recogni* corpus-wide','body_text:recogni*',False),('recogni* on-topic 41 vols','body_text:recogni*',True),('"department of state" corpus-wide','body_text:"department of state"',False),('"department of state" on-topic 41 vols','body_text:"department of state"',True)]:
    L=hits(match,restrict); S=sample(L)
    key='recogni*' if label.startswith('recogni') else 'department of state'
    strict,tol=tests[key]
    ss=sum(1 for v,d in S if re.search(strict,text(v,d),re.I))
    tt=sum(1 for v,d in S if re.search(tol,text(v,d),re.I))
    print(f"{label}: hit list N={len(L)}; sample 40 (indices floor(i*N/40)); STRICT (case-insensitive, single spaces, literal words) {ss} of 40; TOLERANT (case-insensitive, inflections, any run of space/hyphen/comma/paren/full stop) {tt} of 40")
