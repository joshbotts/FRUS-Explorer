import sqlite3,json,re,sys
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
ATT="Agent finding, run f10, 2026-10-31: "
# (heading, prose, [ (vol,doc, note, [excerpts]) ... ])
S=[]
S.append(("1. Before an information agency: schools, indemnity funds and the closing of USIS in China (1931-1949)",
 "The earliest soft-power-like instruments in the set are educational: the Boxer indemnity remission and American schools in China, then USIS and the Fulbright money after 1945. These three documents show how officials framed them and how the Chinese Communist authorities ended USIS in 1949. The set is thin here (the corpus says nothing in the later vocabulary of 'soft power', and the bundled archival indexes barely reach this period).",
 [("frus1931v03","d939","A 1931 conversation in which a Chinese education official cites the Boxer indemnity remission as an American example, and the American consul general stresses US interest in Chinese education.",
   ["Mr. Peck referred to the interest taken by the American Government in educational affairs in China, and said that this was a subject to which special attention would be given."]),
  ("frus1948v07","d55","The Embassy prefers USIS to Fulbright funds as the instrument against anti-American feeling in Chinese universities, and treats the Fulbright programme as longer-range.",
   ["Embassy believes USIS (United States Information Service) is better instrument for this purpose and in any event does not see how the Fulbright money could be used unless an outright grant were made to USIS."]),
  ("frus1949v08","d1576","The Shanghai consulate's protest at the closure of USIS in July 1949; it shows how the Americans described the programme's value to its audience when access ended.",
   ["The cessation of these cultural and technical services of the United States Information Service means a corresponding impoverishment of the cultural and technical resources available to the people of China."])]))
S.append(("2. What officials believed about Asian audiences, and how they judged their own programs (1950-1955)",
 "Four documents from the first decade of the Cold War show the beliefs the strategies rested on: that Asians wait to see who is winning, that neutralism and race feeling are the openings Communist propaganda exploits, and that films, publications and English classes work even though their effect 'cannot be accurately measured'. Success is reported as activity (audiences, copies, classes), not as changed opinion.",
 [("frus1950v06","d32","Ambassador Jessup's oral report on his 1950 Asian tour: his sixth point reports the French and British view of Asian psychology; his ninth calls for unity on the propaganda front.",
   ["Both Pignon, the French High Commissioner for Indochina, and MacDonald, Commissioner for the United Kingdom in Southeast Asia, believe that the Asians are inclined by their psychology to wait and see who is winning."]),
  ("frus1952-54v13p1","d116","The Saigon Embassy's 1952 answer to a Senate inquiry on the information programme's objectives and effectiveness. Reached first through a vector neighbour of 1966 PAO summary (not through a full-text query).",
   ["Since many new customs FE can be traced to Amer films, must be assumed that films is effective program though difficult to determine degree.",
    "All factors recited must be viewed as effective though degree cannot be accurately measured."]),
  ("frus1952-54v12p2","d403","The Psychological Strategy Board's 1953 plan for Thailand: information is one strand of a political-psychological programme that also includes para-military and ethnic-bond operations.",
   ["Through the stimulus of appropriate psychological programs, the ethnic bonds of the Thai peoples scattered through Thailand, Laos, Cambodia, Vietnam, Burma, and China may be able to contribute at the proper time to the psychological and military effort to prevent communist expansion and weaken its focal centers in China, Indochina, and elsewhere."]),
  ("frus1955-57v09","d190","USIA's own August 1955 appraisal for the National Security Council: Far East audiences, Bandung, neutralism, and fear of atomic weapons used against Asian peoples.",
   ["In the Far East USIA was forced to deal with mixed emotions regarding the use of atomic weapons against Asiatic peoples, and to counter communist propaganda designed to stir up race hatred.",
    "USIA concentrated on activities to strengthen the resolution of U.S. allies, orient Asian neutralists toward the U.S., and counter Communist attempts to soften Asian resistance to varied forms of penetration."])]))
S.append(("3. In Vietnam the message became a war program, and the agency's own research said the message was not the problem (1964-1967)",
 "From 1964 USIA took over the Saigon government's information effort and the American psychological-warfare effort. The Director called it the weakest part of the war; a field reviewer blamed Vietnamese motivation; USIA's survey in Long An found apathy produced by insecurity and ineffective government; and by 1967 an internal review argued the agency had taken on tasks outside its sphere.",
 [("frus1964-68v01","d122","Director Rowan reports to the President that information and psychological warfare is the weakest part of the war operation and proposes advisors in every area.",
   ["I came to the conclusion that the weakest part of the war operation, both on our part and that of the Government of South Viet-Nam, is in the field of information and psychological warfare."]),
  ("frus1917-72PubDipv07","d32","A USIA field review of Vietnam, 1964. Reached first through a vector neighbour of the 1966 PAO summary. It states a belief about the Vietnamese public that should be read as the reviewer's, not as evidence about Vietnamese.",
   ["The number one problem in Vietnam is motivation.",
    "But the Vietnamese civil population, family-oriented, selfish and opportunistic even in the best of times, has virtually nothing to lead it or inspire it now."]),
  ("frus1964-68v02","d160","Rowan tells the President in February 1965 that efforts to build national unity have not progressed to his satisfaction, and lists the staff built up.",
   ["efforts to develop among the South Vietnamese people a sense of national unity and a determination to fight off Communist aggression, have not progressed to my satisfaction."]),
  ("frus1964-68v02","d172","Rowan transmits USIA's Long An survey; the findings put the problem in security and government, not in the message.",
   ["The USIA researchers conclude that the population is largely apathetic and is primarily interested in ending the twenty years of war; they care less as to which side will win, although there appears to be a substantial degree of approval of the Viet Cong."]),
  ("frus1917-72PubDipv07","d147","USIA's 1967 review of its role in limited war and insurgency: three country operations absorb nearly fifteen percent of overseas programming resources.",
   ["Some of these tasks appear to lie outside the Agency\u2019s appropriate sphere of operations.","In Laos, USIS is in effect the Ministry of Information for the Royal Lao Government."])]))
S.append(("4. The audience answered back: racism, imperialism and the limits of persuasion (1963-1970)",
 "Policymakers expected Asian audiences to read American actions through race, colonialism and fear of involvement, and they recorded the measured results: a Japanese poll in 1965, the seizure of USIS libraries in Indonesia in 1964-65, and USIA's 1970 survey after the Cambodia incursion. The State Department also declined USIA's proposal to answer Afro-Asian propaganda in public, for fear of the aid programme in Indonesia.",
 [("frus1917-72PubDipv06","d107","A 1963 memo on how smaller friendly countries 'think we regard them'; the belief is that they feel taken for granted.",
   ["There is considerable justification, I think, for the strong feeling in such countries that we take them for granted."]),
  ("frus1917-72PubDipv06","d126","USIA's May 1963 plan to answer Indonesian-led Afro-Asian propaganda on 'imperialism' and 'neo-colonialism'.",
   ["Such a note could serve as the opening gun in a campaign to set the record straight on “imperialism” and “neo-colonialism”, two terms which have been overworked in Indonesia recently."]),
  ("frus1917-72PubDipv06","d133","State's June 1963 reply: no public campaign against Indonesia, because it might jeopardise the aid programme.",
   ["It has appeared questionable to us, however, whether it would be desirable for the United States to publicize our own démarches to the Indonesian Government."]),
  ("frus1964-68v26","d106","Rowan's February 1965 account of attacks on USIS in Indonesia.",
   ["have created a situation that I can describe only as intolerable.","We shall soon have nothing worthwhile left in the way of an information operation."]),
  ("frus1964-68v26","d109","The Jakarta Embassy's reply: the Indonesian government does not want the libraries.",
   ["Despite what Sukarno, Subandrio and others have said, evidence is clear they do not want our USIS libraries, at least as they now function, and have little interest in USAID."]),
  ("frus1964-68v29p2","d46","Ambassador Reischauer on Japanese opinion of the bombing of North Vietnam, with the only available poll.",
   ["Similarly, the number of persons naming the United States as one of their three favorite countries has dropped from 52 percent to 38 percent since last December and those naming the United States as a country they dislike has risen from 4 percent to 8 percent."]),
  ("frus1917-72PubDipv07","d72","Marks forwards a newspaper publisher's proposal to show Asians that the war is not racist, using Asian-American and African-American public figures.",
   ["He points out that our objectives in South Vietnam are being misunderstood in the Far East and urges that we take certain specific steps to show people in the Far East that we in the United States are united as a nation, that we are not waging a racist war, and that our intentions in Asia are honorable."]),
  ("frus1917-72PubDipv07","d102","Vice President Humphrey summarises ambassadors' replies on local attitudes to Vietnam, including Ambassador Bowles on how the war looked from India.",
   ["He says the war is an uneven contest, as it is now being reported, between the most powerful nations in the world and a tiny nation of farmers in North Vietnam."]),
  ("frus1917-72PubDipv08","d94","USIA's survey after the Cambodia incursion: only Australia and Manila approved; confidence in US judgment fell sharply.",
   ["The change in confidence in U.S. ability to deal wisely with world problems, from before to after U.S. entry into Cambodia, is the most dramatic trend in the present study."])]))
S.append(("5. What practitioners thought worked, and the task after Vietnam (1963-1977)",
 "USIA's field officers concluded that personal contact with elites, low American visibility, binational centres and Asian-led regional themes were what worked, that an image of the United States depends on bilateral relations more than on American publicity, and that visits and achievements (a space flight, an astronaut) moved opinion more than messages did. After 1975 the task became reassurance.",
 [("frus1917-72PubDipv06","d127","Reischauer's account of an American astronaut's 1963 visit to Japan as a public-image success.",
   ["Glenn and his family, through the warmth and sincerity of their personalities and their genuine enthusiasm and friendliness, were effective demonstration of typical American virtues."]),
  ("frus1917-72PubDipv07","d73","The Far East area office's 1966 summary of its Public Affairs Officers' replies: target audiences are elites, personal contact is the most effective medium, and budgets prevent mass efforts.",
   ["In all cases, however, the image of American strength, reliability and friendship is basic to our objectives.",
    "In almost every country of the area, our programs are directed at elite groups: government officials, university and high school teachers, media representatives, top-level business executives.","Personal contact is accepted as our most effective medium, yet the nature of our programs is such that we do too little of it."]),
  ("frus1917-72PubDipv08","d30","August 1969 guidance to USIA media on the Nixon doctrine as a theme: Asian initiatives.",
   ["Peace in Asia—which is a precondition to peace in the world—cannot result primarily from American conceptions but has to involve Asian initiatives and regional and sub-regional arrangements that have an Asian origin."]),
  ("frus1917-72PubDipv08","d31","The 1969 Manila conference of East Asia and Pacific Public Affairs Officers: the image of the US depends more on bilateral issues than on American domestic news; themes of modesty, mutuality and multilateralism; low visibility.",
   ["PAOs emphasized that the image of the US usually depended more on the state of bi-lateral relations (security treaty, Okinawa, Korean military modernization, trade restrictions) than on developments within the US.","Assistant Secretary Green\u2019s emphasis on \u201cmodesty, mutuality and multi-lateralism\u201d"]),
  ("frus1917-72PubDipv08","d34","USIA's 1969 survey of the moon landing's effect on opinion in six countries, including Japan and the Philippines. Reached first through the semantic map (the USIA-policy cluster), not through a full-text query.",
   ["The moon landing improved considerably general opinion of the United States in France, but had a barely significant effect in Britain, Japan, or the Philippines."]),
  ("frus1917-72PubDipv08","d149","USIA's 1971 assessment of overseas Chinese attitudes in Southeast Asia after the US-China thaw; a case of the audience being assessed as a group with its own loyalties.",
   ["The predominant mood is apolitical, seeking to be neutral, and concerned with economic and trade problems rather than strong ideological convictions."]),
  ("frus1977-80v30","d79","A July 1977 USIA memo: the Administration believes it must shore up East Asians' confidence in America's staying power.",
   ["I don’t think there should be any serious doubt that this Administration believes shoring up the confidence of East Asians in America’s long-term staying power and positive involvement in the area is real and necessary."]),
  ("frus1977-80v30","d81","State asks posts in July 1977 for views on the future role of public diplomacy in Asia.",
   ["I would welcome any comments that you, in collaboration with your PAOs, might have on the future role of public diplomacy in support of our policies in Asia."]),
  ("frus1977-80v30","d83","The Jakarta Embassy's reply: Indonesians persistently believe the US is withdrawing, and see the human-rights message as accusatory.",
   ["We still face deeply implanted and persistent feeling that new administration is “withdrawing” or, at least, “reducing priority” in East Asia."])]))
# --- verify
sel="SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0"
def norm(s): return " ".join(s.split())
dates=dict(((l.split("\t")[0],l.split("\t")[1]),l.split("\t")[4]) for l in open(R+"coll_sources.tsv"))
seen=set(); entries=[]; checks=[]; ok=True
for head,prose,docs in S:
    entries.append({"kind":"heading","text":head,"level":1})
    entries.append({"kind":"prose","text":prose})
    docs=sorted(docs,key=lambda d:dates[(d[0],d[1])])
    for v,d,note,exc in docs:
        assert not v.endswith("Ed2")
        assert (v,d) not in seen; seen.add((v,d))
        r=db.execute(sel,(v,d)).fetchone()
        if not r: print("MISSING",v,d); ok=False; continue
        full=norm((r[0] or "")+" "+(r[1] or "")+" "+(r[2] or "")+" "+r[3]); body=norm(r[3])
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[ATT+note]})
        for e in exc:
            inb=norm(e) in body
            checks.append((v,d,len(e),inb,e))
            if not inb: print("EXCERPT NOT IN BODY",v,d,e[:80]); ok=False
            entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":e})
entries.append({"kind":"heading","text":"Threads this run could not follow","level":1})
entries.append({"kind":"prose","text":"Not followed: (1) the pre-1940 period beyond the Boxer indemnity (no instrument in the corpus matches the later idea of 'soft power', and the bundled archival indexes reach only 11 of 695 series before 1940); (2) opinion data other than USIA's own surveys, since the corpus prints few of the surveys and none of the underlying questionnaires; (3) Korea, the Philippines and Australia, which appear here only in passing; (4) Chinese-language and Japanese-language sources, which would show how the messages were received; (5) USIA Far East area-office files themselves (Record Group 306), which the bundled indexes do not resolve to a catalogued series; (6) the 1955-1960 and 1971-1976 gaps in the public-diplomacy volumes, where the run read little; (7) whether the policymakers' beliefs about Asian audiences were accurate, which FRUS cannot show."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
intro=("What FRUS answers directly: about thirty documents in 105 indexed volumes (of the 553-volume series) show how American officials assessed the effect of information, cultural and psychological programs on audiences in East Asia and the Pacific from 1931 to 1977, what messages they chose, and what they believed about the audience. "
"Where FRUS points for the rest: the documents came mainly from State Department central files, the records of the United States Information Agency (Record Group 306) and presidential libraries; the editors' footnotes cite, without printing, the National Security Council policy papers (State lot 63 D 351), and the Kennedy, Johnson, Nixon and Carter library files. "
"What this request cannot get from FRUS: any measure of what Asian audiences actually thought, apart from USIA's own surveys; the phrase 'soft power' (zero documents); and the Far East area-office files of USIA.")
doc={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,"name":"American soft power in East Asia and the Pacific - run f10",
 "authorLine":"Agent run f10, 2026-10-31","introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":entries}
if ok:
    json.dump(doc,open(R+"collection.fruscollection","w"),indent=1,ensure_ascii=False)
    with open(R+"quote_checks.tsv","w") as f:
        for v,d,l,inb,e in checks: f.write("%s\t%s\t%d\t%s\t%s\n"%(v,d,l,inb,e))
    print("WROTE collection: documents",len(seen),"excerpts",len(checks),"entries",len(entries))
    open(R+"queries.log","a").write("python3 build_coll.py  # verifies every pair with: "+sel+"  and every excerpt as a substring of whitespace-collapsed body_text; writes collection.fruscollection and quote_checks.tsv\n")
else: print("NOT WRITTEN")
