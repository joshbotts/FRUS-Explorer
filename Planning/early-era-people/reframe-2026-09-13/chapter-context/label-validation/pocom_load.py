#!/usr/bin/env python3
"""POCOM -> pocom-posts.json: every chief-of-mission and every principal appointment with
dates, plus people (surname, forename, genName). Read-only over the POCOM checkout."""
import re, glob, json, os, collections
P="/Users/jbotts/Development/pocom"
def g(tag,blk):
    m=re.search(r"<%s>\s*<date>([^<]*)</date>"%tag,blk); return m.group(1).strip() if m and m.group(1).strip() else None
people={}
for f in sorted(glob.glob(P+"/people/*/*.xml")):
    t=open(f,encoding="utf-8").read()
    sid=re.search(r"<id>([^<]+)</id>",t).group(1)
    sur=re.search(r"<surname>([^<]*)</surname>",t); fn=re.search(r"<forename>([^<]*)</forename>",t); gn=re.search(r"<genName>([^<]*)</genName>",t)
    people[sid]={"surname":sur.group(1).strip() if sur else "","forename":fn.group(1).strip() if fn else "","genName":gn.group(1).strip() if gn else ""}
posts=[]
for f in sorted(glob.glob(P+"/missions-countries/*.xml")):
    t=open(f,encoding="utf-8").read()
    terr=re.search(r"<territory-id>([^<]+)</territory-id>",t).group(1)
    for blk in re.findall(r"<chief>.*?</chief>",t,re.S):
        posts.append({"kind":"mission","file":os.path.basename(f),"territory":terr,
            "contemporary":(re.search(r"<contemporary-territory-id>([^<]*)<",blk) or [None,None])[1],
            "person":re.search(r"<person-id>([^<]+)<",blk).group(1),"role":re.search(r"<role-title-id>([^<]+)<",blk).group(1),
            "id":re.search(r"<id>([^<]+)<",blk).group(1),
            "appointed":g("appointed",blk),"started":g("started",blk),"ended":g("ended",blk)})
for f in sorted(glob.glob(P+"/positions-principals/*.xml")):
    t=open(f,encoding="utf-8").read()
    pos=re.search(r"<id>([^<]+)</id>",t).group(1)
    for blk in re.findall(r"<principal>.*?</principal>",t,re.S):
        posts.append({"kind":"principal","file":os.path.basename(f),"position":pos,
            "person":re.search(r"<person-id>([^<]+)<",blk).group(1),"role":(re.search(r"<role-title-id>([^<]+)<",blk) or [None,None])[1],
            "id":re.search(r"<id>([^<]+)<",blk).group(1),
            "appointed":g("appointed",blk),"started":g("started",blk),"ended":g("ended",blk)})
json.dump({"people":people,"posts":posts},open("pocom-posts.json","w"))
fmt=collections.Counter()
for p in posts:
    for k in ("appointed","started","ended"):
        v=p[k]; fmt[(k,"none" if v is None else re.sub(r"\d","9",v))]+=1
print(len(people),"people",len(posts),"posts"); print(sorted(fmt.items()))
print([p for p in posts if p["kind"]=="principal" and p["position"] in("secretary","assistant-secretary","second-assistant-secretary") and (p["appointed"] or "")[:4] in ("1872","1873","1869")])
