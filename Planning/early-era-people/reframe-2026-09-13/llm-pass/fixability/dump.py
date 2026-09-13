import json,sys
d=json.load(open('/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/Planning/early-era-people/feasibility-2026-09-12/measure-errors/errors.json'))
arm,kind=sys.argv[1],sys.argv[2]
L=d['arms'][arm][kind]
for i,x in enumerate(L):
    if kind=='false_positives':
        extra="ov=%s ed=%d oth=%s"%(int(x['overlaps_gold']),len(x['editor_overlap']),','.join(a[:5] for a in x['in_other_arms']))
    else:
        extra="po=%s edc=%d oth=%s fl=%s"%([p.get("n",p) if isinstance(p,dict) else p for p in x["pred_overlapped"]],int(x["editor_covers"]),','.join(a[:10] for a in x['found_by_other_arms']),x.get('flags'))
    print("%03d %s %s/%s %s | %s | …%s⟦%s⟧%s… | %s"%(i,x['band'][:4],x['v'],x['d'],x['category'],extra,x['left'][-40:],x['n'],x['right'][:35],''))
