import json,sys,collections
for g in ("all","head"):
    o=json.load(open(f"chapter_candidates-{g}.json"))
    for W in ("pm0","pm1"):
        b=o["by_window"][W]; tot=collections.Counter(); per={}
        for k,c in b["cross"].items():
            if "|secstate" in k: continue
            kind,t=k.split("|")
            role = None
            if kind in ("despatch-high","despatch-medium") and t=="from": role="US-chief-expected"
            if kind in ("instr+notesTo","instructions","notesTo") and t=="to": role="US-chief-or-foreign-envoy"
            r=collections.Counter()
            for cell,n in c.items():
                chap,base=cell.split(" x ")
                r["rows"]+=n; r["base:"+base]+=n
                if "agree-unique" in chap and base=="one": r["one:corroborated-by-chapter"]+=n
                elif base=="one" and chap.startswith("chiefs"): r["one:chapter-conflict"]+=n
                elif base=="one": r["one:no-chapter-candidate"]+=n
                if "agree-unique" in chap and base=="several": r["several:resolved-by-chapter"]+=n
                if "agree-unique" in chap and base=="nobody": r["nobody:chapter-agrees(!)"]+=n
            per[k]=(role,dict(r))
            for x,y in r.items(): tot[x]+=y
        print(f"== grain={g} window={W} rows={b['fromto_rows_in_1861_1899_docs']}")
        print("   TOTAL", dict(tot))
        for k in ("despatch-high|from","despatch-medium|from","instr+notesTo|to","instructions|to","notesTo|to","nothing|from","nothing|to"):
            if k in per: print("  ",k,per[k][0],per[k][1])
        for k in ("instr+notesTo|from|secstate","instructions|from|secstate","notesTo|from|secstate"):
            if k in b["tally"]: print("  ",k,b["tally"][k])
