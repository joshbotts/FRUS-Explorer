import re,json,sqlite3
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
norm=lambda s:" ".join(s.split())
cites={}
for l in open(R+"cites.tsv"):
    k,s,u=l.rstrip("\n").split("\t"); cites[k]=(s,u)
qc=[l.rstrip("\n").split("\t") for l in open(R+"quote_checks.tsv")]
Q=[(f"Q{i+1}",v+"/"+d,e) for i,(v,d,ln,inb,e) in enumerate(qc)]
ov=open(R+"overview.md").read().split("## The bottom line",1)[1]
quotes=re.findall(r"“([^”]+)”",ov)+re.findall(r'"([^"]+)"',ov)
skip={"soft power","Vietnam Special Caption Messages","Military Telegrams Relating to Korea","American soft power in East Asia and Pacific - run f10","information program","prestige","Department of State","psychological","image"}
trace_q=[]
for q in quotes:
    qq=norm(q)
    if qq in skip: continue
    hit=[n for n,doc,e in Q if qq in norm(e)]
    trace_q.append((qq,hit[0] if hit else "NONE",[doc for n,doc,e in Q if n==hit[0]][0] if hit else ""))
seen=set(); tq=[]
for a,b,c in trace_q:
    if (a,b) in seen: continue
    seen.add((a,b)); tq.append((a,b,c))
M=open(R+"memo_body.md").read()
qtab="\n".join("| %s | %s | %s |"%(n,doc,e.replace("|","\\|")) for n,doc,e in Q)
ttab="\n".join("| quotation: “%s” | %s (%s) | %s |"%(a.replace("|","\\|"),b,c,"Section 6, verified by the SELECT given there") for a,b,c in tq)
M=M.replace("{{QUOTE_TABLE}}",qtab).replace("{{TRACE_QUOTES}}",ttab)
open(R+"memo.md","w").write(M)
print("quotes in table",len(Q),"traced quotation fragments",len(tq),"unmatched",[x for x in tq if x[1]=="NONE"])
