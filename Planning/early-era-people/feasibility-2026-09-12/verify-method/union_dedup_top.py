import sys, os, json
from collections import Counter
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
import ner_store
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from census_rerun import k1, k2, ARMS
HOME=os.path.expanduser("~")
vols = ner_store.scope_volumes(ARMS["marked"][0])
out={}
for uname,(c1,c2) in {"union_marked_filtered_control":("marked","filtered_control"),"union_marked_filtered_sweep":("marked","filtered_sweep")}.items():
    cnt=Counter(); nrows=0; overlap_rows=0
    for v in vols:
        seen={}
        for comp in (c1,c2):
            store,layer,_=ARMS[comp]
            p=ner_store.layer_path(store,layer,v)
            rows=ner_store.read_jsonl_gz(p) if p else []
            for r in rows:
                key=(r["d"],r["s"],r["e"])
                if key in seen:
                    overlap_rows+=1; continue
                seen[key]=1
                cnt[k2(k1(r["n"]))]+=1
    out[uname]={"dedup_rows":sum(cnt.values()),"overlap_rows":overlap_rows,"top10_dedup":cnt.most_common(10),
                "distinct_K2":len(cnt),"share_singleton":round(sum(c for c in cnt.values() if c==1)/sum(cnt.values()),4),
                "share_ge20":round(sum(c for c in cnt.values() if c>=20)/sum(cnt.values()),4)}
    print(json.dumps({uname:out[uname]},ensure_ascii=False))
json.dump(out,open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"union_dedup_top.json"),"w"),ensure_ascii=False,indent=1)
