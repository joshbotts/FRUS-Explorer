import sqlite3,re,json
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
# (volume, doc, start anchor, end anchor)  -- substring from start through end inclusive
SPEC=[
("frus1949v07p2","d386","A considerably expanded information program","aims and attitudes of the US and the USSR."),
("frus1952-54v12p2","d403","In projecting U.S. leadership, however,","indigenous leadership wherever possible."),
("frus1955-57v09","d189","We can anticipate, too, an upsurge of neutralism.","combat these tendencies."),
("frus1917-72PubDipv06","d135","USIA’s main role in the interagency program","Chinese weakness."),
("frus1917-72PubDipv06","d135","as an overt U.S. agency, our credibility","is relatively low"),
("frus1917-72PubDipv08","d24","Thus modified, Agency objectives for the Midway Meeting","strengthen the public image of:"),
("frus1950v06","d89","At present we are talking over the heads of Southeast Asia","and doing so inadequately."),
("frus1950v06","d89","It is not enough that we try to teach Southeast Asia to understand us;","learn to understand them."),
("frus1958-60v16","d65","Hold or reduce the number of U.S. officials","relatively privileged positions."),
("frus1917-72PubDipv07","d32","Vietnamese peasants are, in the main,","persuaded by other Vietnamese."),
("frus1917-72PubDipv07","d32","But the Vietnamese civil population, family-oriented,","inspire it now."),
("frus1964-68v29p2","d46","Such simplistic attitudes are possible in Japan","past twenty years."),
("frus1964-68v29p2","d46","The only available public opinion poll","from 4 percent to 8 percent."),
("frus1964-68v29p2","d46","the basic emotional response remains unchanged","unchangeable over the short run."),
("frus1955-57v09","d190","Although the national press remained generally unreceptive","was achieved."),
("frus1955-57v09","d207","Despite new strength in the conservative forces","U.S.-Japanese arrangements."),
("frus1964-68v01","d197","there is no conceivable information program","for our side."),
("frus1964-68v01","d197","Vietnamese audiences at USIS film showings","an estimated 28 million."),
("frus1917-72PubDipv07","d73","In almost every country of the area, our programs are directed at elite groups","top-level business executives."),
("frus1917-72PubDipv07","d73","In most programs, however, budget stringencies","meaningful, mass efforts."),
("frus1917-72PubDipv07","d100","The image of a huge white nation","Asian struggle for freedom."),
("frus1917-72PubDipv07","d100","2. more action by Asians, officially and non-officially,","financial support;"),
("frus1917-72PubDipv08","d88","Rating of the U.S. as a dependable ally","“rather dependable.”"),
("frus1964-68v29p2","d123","Racial violence and social unrest in America","less positive political symbol."),
("frus1917-72PubDipv08","d31","Asians are, to varying degrees, America watchers.","at home."),
("frus1917-72PubDipv08","d31","PAOs emphasized that the image of the US","developments within the US."),
("frus1917-72PubDipv08","d149","It is apparent that the emotional pull of China","5 or 10 years ago."),
("frus1969-76ve12","d10","I still believe, as I wrote you six months ago,","Nixon Doctrine."),
("frus1969-76v38p2","d105","The American defeat has been in good part written off","two years ago."),
("frus1969-76v38p2","d105","The denouement in Indochina has left Hong Kong","“very clearly in default.”"),
("frus1969-76v38p2","d105","hoping that we have all learned the lesson that America is not omnipotent","what they should be doing themselves."),
("frus1977-80v22","d104","Rather than being reassured,","no interest there at all."),
("frus1977-80v30","d79","I don’t think there should be any serious doubt","real and necessary."),
("frus1977-80v30","d83","We still face deeply implanted and persistent feeling","priority” in East Asia."),
("frus1977-80v30","d83","Full appreciation for President Carter’s broad","special needs of developing societies."),
("frus1977-80v30","d152","The enlarged scope for ICA","perceptions of each other."),
]
out=[]; bad=0
for v,d,a,b in SPEC:
    body=db.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    t=re.sub(r"\s+"," ",body)
    i=t.find(a); 
    if i<0: print("NO START",v,d,a); bad+=1; continue
    j=t.find(b,i)
    if j<0: print("NO END",v,d,b); bad+=1; continue
    s=t[i:j+len(b)]
    n=t.count(s)
    print("%s/%s len %d occurrences %d | %s"%(v,d,len(s),n,s[:110]+" ... "+s[-40:]))
    if len(s)>700: print("   WARNING long excerpt")
    out.append({"v":v,"d":d,"text":s})
json.dump(out,open("excerpts.json","w"),ensure_ascii=False,indent=1)
print("excerpts",len(out),"problems",bad)
