import json,re,sqlite3
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
Q={q['id']:q for q in json.load(open('quotes.json'))}
ATT="Agent run on U.S. persuasion in East Asia and the Pacific, 2026-10-31: "
intro=("What FRUS answers directly: The phrase \"soft power\" appears in no document of the series, so the question is read as one about information programs, psychological operations and educational and cultural exchange. On that reading FRUS answers it well for 1949 to 1978. "
"Officials treated persuasion as a companion to aid and arms, aimed at peoples they thought poorly informed about America. From the 1950s they preferred to work through local governments and keep Americans out of sight. "
"Their own verdicts were sober: the Information Agency's director called information and psychological work the weakest part of the war effort in Vietnam, an adviser argued that deeds outweighed broadcasts, and by 1975 a field post judged security programs to lack credibility. "
"Where FRUS points for the rest: the printed documents came from the Information Agency's director's and plans files (Record Group 306), State Department central files and Operations Coordinating Board files (Record Group 59) and the Johnson Library's National Security File; the footnotes cite without printing, most often, the State Department's National Security Council policy-paper records (NARA identifier 2839192), the Johnson Library's National Security File, the Nixon National Security Council files and the Kennedy Library's National Security Files. "
"What this request cannot get from FRUS: audiences' own reactions beyond a few quoted polls, the broadcasts and publications themselves, the Agency's research reports (look in its record group), and any systematic record of the exchange programs for Japan, Korea and the Philippines. \"Soft power\" itself was searched across the whole series and found nowhere.")
H=[
("Before 1945: a precedent under another name",
 "The closest precedent before 1945 was financial rather than informational: the return of the Boxer indemnity to China for education and culture. This one document is kept as the earliest example of the thread, not as an assessment of its effect.",
 [("frus1924v01","d540","The Secretary of State asks the President to approve remitting the Boxer indemnity to a China Foundation for the Promotion of Education and Culture, and calls the return a demonstration of friendship; it is a precedent under another name, with no judgment of its effect on Chinese opinion.",["Q32"])]),
("Persuasion as the companion of aid, 1949–1953",
 "These three documents show how officials first framed persuasion: as an addition to aid and arms, directed at peoples thought to know little of America, and carried out through local leaders.",
 [("frus1949v09","d558","Webb reports that Communist authorities closed Information Service posts in the major Chinese cities while the Voice of America doubled its Mandarin output, and states the aim of fostering rifts between the Chinese Communists and the Soviet Union.",["Q01"]),
  ("frus1950v06","d50","Webb asks the President for money for an intensified information and exchange program in Southeast and South Asia, premised on the peoples' meager knowledge of America and on the need to explain American aid before Communist propaganda misrepresents it.",["Q03"]),
  ("frus1952-54v12p2","d403","The Psychological Strategy Board's plan for Thailand combines information programs with military and economic measures and sets the rule of working through indigenous leadership.",["Q05"])]),
("Keeping the American hand low, 1955–1968",
 "From the mid-1950s the documents show a strategy of speaking through local governments and avoiding the look of foreign propaganda; they also record the beliefs about Asian audiences that supported it.",
 [("frus1955-57v23p2","d50","An embassy cable argues that Asian opinion values the American record of principle and keeping its word, a belief about the audience that shaped the case against abandoning the Korean armistice.",["Q07"]),
  ("frus1955-57v22","d447","The State Department records that the Information Agency resisted expanding its Malayan program for budgetary reasons, a view that the British should do more, and fear of appearing to support colonialism.",["Q06"]),
  ("frus1961-63v23","d289","Murrow lists the Agency's planned steps in Indonesia: civic-action publicity for the army, youth work, American studies chairs, reading rooms and travel, under a rule of patient persistence.",["Q38"]),
  ("frus1917-72PubDipv07","d32","An Agency officer's field review of Vietnam in 1964 blames local government failure and lack of motivation, and concludes that Vietnamese must persuade Vietnamese; it also states a stereotype of the civilian population.",["Q10","Q12"]),
  ("frus1964-68v27","d386","Marks tells the President that Thailand has not given a national information program proper attention and that the Agency runs programs the Thai should take over.",["Q20"])]),
("How the practitioners judged the results, 1964–1966",
 "Here the Agency's directors and officers give their own verdicts: candid about weakness in Vietnam, bitter about Indonesia, and convinced that deeds counted for more than words.",
 [("frus1964-68v01","d122","Rowan tells the President that information and psychological warfare is the weakest part of the war operation and proposes advisers and a crash training program.",["Q13"]),
  ("frus1964-68v26","d106","Rowan reports that Indonesian pressure has left his service almost nothing, and urges retaliation rather than voluntary withdrawal, which he says would be read as retreat.",["Q16"]),
  ("frus1964-68v02","d160","Rowan reports some psychological headway in the Hop Tac areas but efforts to build unity have not progressed to his satisfaction.",["Q14"]),
  ("frus1964-68v29p2","d46","The Embassy in Japan reports a fall in the share of Japanese naming the United States among their favorite countries and says that Embassy and information service have done their best to counter the reaction to Vietnam.",["Q19"]),
  ("frus1917-72PubDipv07","d85","An officer of the Agency argues that the psychological effect of the American presence depends on what Americans do rather than on what the joint public affairs office says.",["Q18"])]),
("Retrenchment, reassurance and China, 1969–1978",
 "After the Nixon Doctrine and then the fall of South Vietnam the Agency's task in the region shifted from persuading to reassuring; China became a new audience.",
 [("frus1917-72PubDipv08","d31","A summary of the Agency's Manila conference of public affairs officers records views on how Asians watch America, how prestige is judged, and what programs to prefer, including binational centers and low American visibility.",["Q22","Q23"]),
  ("frus1917-72PubDipv08","d58","A 1969 summary describes the transfer of the Vietnam information and psychological operations program to the Vietnamese government.",["Q21"]),
  ("frus1917-72PubDipv08","d99","The Agency's first program memorandum, found by similarity to another document and not by a word search, tells the Agency to lower its voice and to disengage from information support to governments in Southeast Asia.",["Q35","Q36"]),
  ("frus1917-72PubDipv08","d146","The Agency's East Asia chief proposes psychological initiatives to turn the opening to Peking into a lasting asset.",["Q27"]),
  ("frus1917-72PubDipv08","d149","A survey of the Agency's posts finds the overseas Chinese of Southeast Asia mainly apolitical and trade-minded, though pleased by the thaw.",["Q26"]),
  ("frus1969-76v38p2","d105","Post-by-post reassessments after the fall of Vietnam show doubts in Korea, Thailand and the Philippines about American staying power; Thailand reports that security-themed programs lack credibility while policy is unsettled.",["Q28"]),
  ("frus1977-80v30","d79","The Agency's East Asia chief reads Administration policy as aiming to shore up East Asian confidence in America's staying power.",["Q30"]),
  ("frus1977-80v30","d152","Mort Smith reports from Peking on the scope of the exchange, translation, film and exhibit programs now open to the Agency in China.",["Q31"])]),
]
entries=[]
seen=set()
for h,pr,docs in H:
    entries.append({"kind":"heading","text":h,"level":1})
    entries.append({"kind":"prose","text":pr})
    for v,d,note,qs in docs:
        assert (v,d) not in seen; seen.add((v,d))
        r=c.execute("SELECT body_text,is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        assert r and r[1]==0 and r[2]==0,(v,d)
        assert not v.endswith('Ed2')
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[ATT+note]})
        body=re.sub(r'\s+',' ',r[0])
        for qid in qs:
            q=Q[qid]; assert (q['v'],q['d'])==(v,d),(qid,v,d)
            assert re.sub(r'\s+',' ',q['text']) in body,qid
            entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":q['text']})
entries.append({"kind":"heading","text":"Threads not followed","level":1})
entries.append({"kind":"prose","text":"Several threads could not be followed in this run. The educational-exchange record for Japan, Korea and the Philippines, including the cultural committees agreed with Japan in 1961, was not read systematically. Voice of America content, leaflets and publications are not in the volumes. The Agency's own research and poll reports, which would test the officials' beliefs about audiences, were not located. The Boxer-indemnity thread before 1945 stops at one document. Terms such as image, prestige and face were not searched as a family, and the Philippine and Indonesian assessments of the 1950s were read only through the documents above."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
doc={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
"name":"Persuasion in East Asia and the Pacific, 1924–1978",
"authorLine":"Agent run on U.S. persuasion in East Asia and the Pacific, 2026-10-31",
"introductionText":intro,
"composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
"entries":entries}
json.dump(doc,open('collection.fruscollection','w'),ensure_ascii=False,indent=2)
nd=sum(1 for e in entries if e['kind']=='document'); ne=sum(1 for e in entries if e['kind']=='excerpt')
print('docs',nd,'excerpts',ne,'intro words',len(intro.split()))
