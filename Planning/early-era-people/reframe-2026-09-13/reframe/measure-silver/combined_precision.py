#!/usr/bin/env python3
"""INFERRED arithmetic on silver2.json (measured counts): the surname x year rule's agreement over ALL crosswalked linked
from/to heads, positive silver (slug) AND negative silver (crosswalk id, no slug), per band. A pick on a negative row
is counted wrong; the 'possible registry miss' picks are reported both ways (as wrong, and removed)."""
import json, math
d=json.load(open("silver2.json"))["tables"]
def wilson(k,n,z=1.96):
    p=k/n; den=1+z*z/n; c=(p+z*z/(2*n))/den; h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den
    return [round(p,4),round(c-h,4),round(c+h,4)]
out={}
for bd in ("1861-1899","1900-1929","1930-1945","1946-"):
    pos=d["silver_heads"].get(bd,{}); neg=d["negative_heads_crosswalk_no_slug"].get(bd,{})
    agree=pos.get("S_agree",0); picks=pos.get("S_picks",0)+neg.get("S_false_picks",0)
    miss=neg.get("S_false_picks_possible_registry_miss",0)
    out[bd]={"positive_rows":pos.get("rows",0),"negative_rows":neg.get("rows",0),"S_picks_total":picks,"S_agree":agree,
             "S_wrong_on_positive":pos.get("S_disagree",0),"S_false_picks_on_negative":neg.get("S_false_picks",0),
             "precision_positive_only":wilson(agree,pos["S_picks"]) if pos.get("S_picks") else None,
             "precision_positive_plus_negative":wilson(agree,picks) if picks else None,
             "precision_excluding_possible_registry_miss":wilson(agree,picks-miss) if picks-miss else None,
             "negative_share_of_crosswalked_heads":round(neg.get("rows",0)/max(1,pos.get("rows",0)+neg.get("rows",0)),4)}
json.dump(out,open("combined-precision.json","w"),indent=1); print(json.dumps(out,indent=1))
