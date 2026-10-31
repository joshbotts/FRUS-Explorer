import re,json
Q=[
("Q01","frus1949v09","d558","One of the objectives of the Voice of America and other informational programs within China is to foster possible rifts between Chinese Communists and the USSR"),
("Q02","frus1949v09","d558","As other informational and cultural channels become progressively restricted, the importance of the Voice of America program increases."),
("Q03","frus1950v06","d50","the generally meager knowledge and understanding of the United States on the part of the peoples of this area"),
("Q04","frus1950v06","d50","Comparatively few nationals understand the current policies of the United States or the history and tradition of this country."),
("Q05","frus1952-54v12p2","d403","In projecting U.S. leadership, however, we must work with and through indigenous leadership wherever possible."),
("Q06","frus1955-57v22","d447","a fear of placing the U.S. in the position of appearing to support colonialism"),
("Q07","frus1955-57v23p2","d50","the U.S. position in Asia rests in large part upon Asian appreciation that U.S. policy is based on principles, including observance of the pledged word"),
("Q08","frus1961-63v23","d289","Earnest, persistent efforts will be made to establish “chairs” in American studies at the larger universities of Indonesia."),
("Q09","frus1961-63v23","d289","we should refrain from glamorous, immediate-impact actions"),
("Q10","frus1917-72PubDipv07","d32","Vietnamese peasants are, in the main, going to be persuaded by other Vietnamese."),
("Q11","frus1917-72PubDipv07","d32","The number one problem in Vietnam is motivation."),
("Q12","frus1917-72PubDipv07","d32","the Vietnamese civil population, family-oriented, selfish and opportunistic even in the best of times"),
("Q13","frus1964-68v01","d122","the weakest part of the war operation, both on our part and that of the Government of South Viet-Nam, is in the field of information and psychological warfare"),
("Q14","frus1964-68v02","d160","have not progressed to my satisfaction"),
("Q15","frus1964-68v02","d160","we have made some psychological headway during the past year, particularly in the Hop Tac areas"),
("Q16","frus1964-68v26","d106","We shall soon have nothing worthwhile left in the way of an information operation."),
("Q17","frus1964-68v26","d106","Such an action would be interpreted by both our enemies and friends as a retreat and as knuckling under to communist pressure."),
("Q18","frus1917-72PubDipv07","d85","The psychological effect of the American presence in Viet-Nam will, needless to say, be effective primarily through what Americans, both here and there, do rather than through what JUSPAO says or prints."),
("Q19","frus1964-68v29p2","d46","the number of persons naming the United States as one of their three favorite countries has dropped from 52 percent to 38 percent since last December"),
("Q20","frus1964-68v27","d386","The Thai Government has not given proper attention to the need for a national information program designed to gain popular support."),
("Q21","frus1917-72PubDipv08","d58","USIA has, from the beginning, considered its psychological operations (PSYOP) support program in Viet-Nam as short-term in nature."),
("Q22","frus1917-72PubDipv08","d31","Asians are, to varying degrees, America watchers."),
("Q23","frus1917-72PubDipv08","d31","But there was general agreement that US prestige is diminished when we are not able to solve our own problems at home."),
("Q24","frus1917-72PubDipv08","d31","the image of the US usually depended more on the state of bi-lateral relations (security treaty, Okinawa, Korean military modernization, trade restrictions) than on developments within the US"),
("Q25","frus1917-72PubDipv08","d31","the total exercise as presently constituted has not been worth the effort"),
("Q26","frus1917-72PubDipv08","d149","The predominant mood is apolitical, seeking to be neutral, and concerned with economic and trade problems rather than strong ideological convictions."),
("Q27","frus1917-72PubDipv08","d146","build what is now a temporary psychological asset into a long-range one"),
("Q28","frus1969-76v38p2","d105","programs on U.S. security relations in Asia lack credibility and may in fact do damage to our relations"),
("Q29","frus1969-76v38p2","d105","Thais still see us as friends and admire much in the American system."),
("Q30","frus1977-80v30","d79","shoring up the confidence of East Asians in America’s long-term staying power and positive involvement in the area is real and necessary"),
("Q31","frus1977-80v30","d152","The enlarged scope for ICA -funded activities is real and important to the future of US – PRC relations and to perceptions of each other."),
("Q32","frus1924v01","d540","At the moment this Government is demonstrating its friendship for China by the return of the Indemnity"),
("Q33","frus1917-72PubDipv08","d31","Many PAOs saw little evidence of intellectual interest in US racial, urban and student disorders and their causes."),
("Q34","frus1964-68v01","d122","It is my judgment that the Viet-Namese people will never give sufficient support to the war effort until certain glaring gaps are closed in the information-psychological campaign."),
("Q38","frus1961-63v23","d289","patient persistence"),
("Q39","frus1917-72PubDipv08","d31","Exposures as a main pillar of PPBS should be dropped."),
("Q35","frus1917-72PubDipv08","d99","The President’s concept of partnership suggests that the U.S. will have to lower its voice."),
("Q36","frus1917-72PubDipv08","d99","While the Agency still has a major commitment to programs in Southeast Asia flowing from the overall U.S. engagement there, it will disengage as rapidly as feasible from information support to governments there."),
("Q37","frus1917-72PubDipv08","d99","Far from taking for granted a favorable psychological climate in Japan and key countries of Western Europe"),
]
def norm(s): return re.sub(r'\s+',' ',s)
res=[]
for qid,v,d,t in Q:
    body=norm(open(f"docs/{v}__{d}.txt").read().split('BODY:',1)[1])
    ok = norm(t) in body
    res.append((qid,v,d,ok))
    print(qid,v+'/'+d,'OK' if ok else 'MISSING')
json.dump([{'id':q,'v':v,'d':d,'text':t} for q,v,d,t in Q],open('quotes.json','w'),ensure_ascii=False,indent=1)
