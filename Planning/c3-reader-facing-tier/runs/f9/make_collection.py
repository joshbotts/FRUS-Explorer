import json
A="Agent finding, run f9, 2026-10-31: "
Q={l.split('\t')[0]:l.rstrip('\n').split('\t') for l in open('quotes.tsv')}
def doc(v,d,note): return {"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]}
def ex(q): _,v,d,t=Q[q]; return {"kind":"excerpt","volumeId":v,"documentId":d,"text":t}
intro=("What FRUS answers directly: from 1949 to 1980 officials judged America's standing in East Asia less by American culture than by whether Asians believed American commitments; "
"they aimed their information programmes chiefly at elites (with village campaigns in Vietnam, Laos and Thailand), judged success mostly by press placement, attendance and anecdote, with few polls, "
"and built their messages on explicit beliefs about a race-conscious, nationalist, 'Oriental' audience. 25 documents, from about 2,000 in 84 volumes that use the information programme's vocabulary. "
"Where FRUS points for the rest: came-from — USIA records in RG 306 (Director's Subject Files 1968–72, Entry A1–42; JUSPAO General Records 1966–75, Entry A1–31; Director's Subject Files 1963–69, Entry UD WW 257; Office of Policy and Plans, Entry P–207; no NARA identifier in the bundled data), "
"and RG 59: OCB papers in Lot 62 D 430 (NAID 2839191, 1953–61, partly restricted), NSC policy papers in Lot 63 D 351 (NAID 2839192, 1947–79, partly restricted), Vietnam Working Group Lot 67 D 54 (NAID 631403, 1963–74, unrestricted), the Central Decimal File and the Central Foreign Policy File; "
"pointed-at — Lot 62 D 430, Lot 66 D 95 (NAID 2839192), USIA Office of Policy and Plans Subject Files Lot 59 D 260 (RG 306, NAID 1257679, 1953–71, partly restricted), Policy Planning Council Lot 65 D 101 (NAID 1136548). "
"What this request cannot get from FRUS: the phrase 'soft power' (0 documents in 84 volumes; controls held); USIA's audience research itself (about 160 documents mention polls or surveys with the agencies, but reports sit in RG 306 Office of Research files); "
"the Pacific islands (6 documents); measured results of exchanges (not read).")
E=[]
E+= [{"kind":"heading","text":"1. The image followed the credibility of American commitments","level":1},
 {"kind":"prose","text":"Why these documents: they are the officials' own statements of what Asian opinion of the United States turned on, from Jessup's 1949 outline to the post-Indochina post reports and the Carter administration's public diplomacy. The thread is the belief that policy and staying power, not culture, set the image."},
 doc("frus1949v07p2","d386","Jessup's outline of Far Eastern and Asian policy for the President puts the basic attitude of Asian peoples toward the U.S. above short-term politics and calls for an expanded information program sympathetic to Asian nationalism."), ex("Q1"),
 doc("frus1917-72PubDipv08","d31","Summary of the 1969 Manila conference of USIA public affairs officers: the US image depends more on bilateral relations than on domestic events; Japan's image in Southeast Asia is poor."), ex("Q2"), ex("Q3"), ex("Q26"),
 doc("frus1969-76v38p2","d105","Post-by-post reports after the fall of Indochina (May 1975): Japan, Korea, Thailand, the Philippines, Indonesia, Singapore, Malaysia, Hong Kong, Taiwan and Burma all read credibility of commitments as the issue."), ex("Q4"),
 doc("frus1977-80v30","d79","USIA's East Asia director restates the Carter administration's aim as restoring East Asian confidence in American staying power."), ex("Q6"),
 doc("frus1977-80v30","d83","Jakarta's answer to Holbrooke: public diplomacy effective, but a persistent belief that the U.S. is withdrawing, and human-rights messaging heard as accusatory."), ex("Q33"), ex("Q5")]
E+= [{"kind":"heading","text":"2. Elites first, villages argued over","level":1},
 {"kind":"prose","text":"Why these documents: they state who the programmes aimed at, from Saigon in 1952 to the 1966 summary of every Far East post's plan, with the Thailand psychological strategy and the 1964 Vietnam inspection between. The thread is a standing elite strategy, repeatedly challenged in counterinsurgency settings."},
 doc("frus1952-54v13p1","d116","Saigon's 1952 report on information objectives and effectiveness: leader groups targeted, rural majority conceded to Viet Minh propaganda. Reached only through semantic neighbours of the 1969 Manila summary, then read."), ex("Q30"), ex("Q7"),
 doc("frus1952-54v12p2","d403","Psychological Strategy Board paper on U.S. psychological strategy based on Thailand (1953): work through indigenous leadership and local cultural attitudes."), ex("Q31"), ex("Q10"),
 doc("frus1955-57v09","d190","NSC status report on the information program (August 1955): Far East section on Japan neutralism, Thai indoctrination campaigns, Bandung, and race-hatred propaganda."), ex("Q32"),
 doc("frus1917-72PubDipv07","d32","Tull's 1964 inspection of USIS Vietnam argues the war will be decided in the hamlets, not among urban elites."), ex("Q9"),
 doc("frus1917-72PubDipv07","d73","1966 summary of Far East PAOs' programmes: elite targeting everywhere, mass programmes only in Vietnam, Laos and Thailand; image of strength, reliability and friendship basic."), ex("Q8"), ex("Q28")]
E+= [{"kind":"heading","text":"3. How effectiveness was judged","level":1},
 {"kind":"prose","text":"Why these documents: they are the places where officials say whether the programme worked, and on what evidence: press usage, column inches, audiences, a visiting astronaut, and one printed poll. The thread is assertion from outputs, with measurement rare and unwelcome."},
 doc("frus1950v06","d31","The expanded USIE program for Southeast Asia (1950): first evidence of success is local press usage of U.S. material."), ex("Q25"),
 doc("frus1955-57v09","d185","NSC status report (March 1955): Japan measured in reprinted column inches, books, films; Korea, Thailand, Burma and the Philippines summarised."), ex("Q11"),
 doc("frus1955-57v09","d207","NSC status report (September 1957): Indonesia judged a programme facing heavy odds; Japan, Philippines and Korea summarised."), ex("Q14"),
 doc("frus1917-72PubDipv06","d127","Reischauer on John Glenn's 1963 visit to Japan as a public-image success, compared with Gagarin's."), ex("Q13"),
 doc("frus1917-72PubDipv08","d88","USIA's May 1970 Saigon opinion survey: confidence in the U.S. as a dependable ally at its lowest in thirteen surveys."), ex("Q12"),
 ex("Q27")]
E+= [{"kind":"heading","text":"4. Vietnam: the American presence as the liability","level":1},
 {"kind":"prose","text":"Why these documents: information officers' warnings, from defoliation in 1961 to the 1965 troop build-up guidance and the 1969 hand-over of psychological operations. The thread is the belief that American actions and presence would speak louder than American messages."},
 doc("frus1961-63v01","d265","USIA's Far East director warns that defoliation would be read across Asia as germ warfare on Asians."), ex("Q15"),
 doc("frus1961-63v02","d16","USIA Far East memorandum (January 1962): the Saigon PAO's view that the GVN's image cannot be better than its own conduct with the press."), ex("Q18"),
 doc("frus1917-72PubDipv07","d48","JUSPAO guidance on presenting the 1965 build-up: assumes foreign presence breeds resentment; frames U.S. role as support for the Vietnamese people."), ex("Q16"),
 doc("frus1917-72PubDipv08","d58","Vietnamization of JUSPAO's information and psychological operations (December 1969)."), ex("Q17")]
E+= [{"kind":"heading","text":"5. Beliefs about the audience","level":1},
 {"kind":"prose","text":"Why these documents: they state what officials believed about Asian audiences — race-conscious, nationalist, reading American motives through local politics, and possessed of an 'Oriental mind'. The phrase family appears in 30 documents in 22 volumes of the scope; the Rangoon telegram is a representative case."},
 doc("frus1947v07","d245","A USIS officer's account of Nanking University students' political attitudes and anti-American feeling in 1947."), ex("Q21"),
 doc("frus1952-54v12p2","d60","Ambassador Sebald from Rangoon (1953): Burmese suspicion of U.S. aid, blamed on failure to explain motives to the 'oriental mind'."), ex("Q34"), ex("Q29"),
 doc("frus1917-72PubDipv08","d149","USIA analysis of overseas Chinese attitudes in Southeast Asia after the U.S.–China thaw (November 1971)."), ex("Q20"),
 ex("Q19")]
E+= [{"kind":"heading","text":"6. China, 1971–1978: restraint and exchange","level":1},
 {"kind":"prose","text":"Why these documents: the opening to Peking forced the information agencies to weigh what not to say as well as what to show. The thread runs from a withheld film and proposed gifts for Nixon's trip to the exchange programme of 1978."},
 doc("frus1917-72PubDipv08","d143","State asks USIA to withhold the Tibetan film 'Man From A Missing Country' before Nixon's China visit."), ex("Q23"),
 doc("frus1917-72PubDipv08","d146","USIA's East Asia office proposes psychological initiatives for the President's trip to Peking (moon rocks, an astronaut, books)."), ex("Q22"),
 doc("frus1977-80v30","d152","The Liaison Office in Peking on staffing for a fast-growing exchange relationship with the PRC (1978)."), ex("Q24")]
E+= [{"kind":"heading","text":"Threads not followed","level":1},
 {"kind":"prose","text":"Not followed in this run: USIA's Office of Research country reports (RG 306), which FRUS summarises only occasionally; the Pacific islands, with 6 documents in scope; the evaluation of Fulbright and other exchanges (about 380 documents found, none read); the wartime cultural relations program with China (1942–1944), outside the chosen period; aid and military civic action as instruments of attraction; Australia and New Zealand as audiences (about 70 documents found, none read)."},
 {"kind":"generated","generatedBlockType":"archivalSources"}]
c={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"American soft power in East Asia and the Pacific — run f9",
 "authorLine":"Agent run f9, 2026-10-31",
 "introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":E}
json.dump(c,open('collection.fruscollection','w'),ensure_ascii=False,indent=1)
print(len(E),'entries')
