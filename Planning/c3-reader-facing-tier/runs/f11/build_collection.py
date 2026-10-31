import json,sqlite3,re
from collections import defaultdict
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
EX=defaultdict(list)
for x in json.load(open("excerpts.json")): EX[(x["v"],x["d"])].append(x["text"])
A="Agent run f11, 2026-10-31: "
SECTIONS=[
("Messaging: contrast, strength and reassurance rather than attraction",
 "These five documents show what officials told themselves the message was for, from 1949 to 1969. The thread is that the message was built from the audience's fears and loyalties, anti-communism, neutralism and doubt about American strength, and never from the appeal of American society alone.",
 [("frus1949v07p2","d386",A+"Jessup, November 1949: a larger information program in non-Communist Asia is wanted to show sympathy with nationalism and to expose Soviet imperialism, with the US and the USSR contrasted by the record."),
  ("frus1952-54v12p2","d403",A+"Psychological Strategy Board plan for Thailand, September 1953: information work is to run through local leaders and local outlets, alongside aid and paramilitary preparation. Image work is one instrument among several."),
  ("frus1955-57v09","d189",A+"Washburn, Acting Director of USIA, to all posts, August 1955: after the Geneva summit the information program is told to expect and combat an upsurge of neutralism."),
  ("frus1917-72PubDipv06","d135",A+"USIA guidance of July 1963 to all posts on blunting the psychological effect of a Chinese nuclear test. The message is American strength delivered calmly; the negative case against China is left to others because USIA's own credibility on it is low."),
  ("frus1917-72PubDipv08","d24",A+"Oleksiw, June 1969, on the Nixon-Thieu Midway meeting: the agency's objectives are written as public images to strengthen. It shows image management stated as a list of effects sought.")]),
("What officials believed about the Asian audience",
 "These four documents are where policymakers say, in their own words, what kind of people they thought they were addressing. The thread is a mix of respect for nationalism and distance from the audience: poor and apathetic, wary of whites, persuaded by their own countrymen, or emotionally pacifist.",
 [("frus1950v06","d89",A+"Final report of the Joint State-Defense survey mission to Southeast Asia, December 1950. Its propaganda section says American information work talks over the audience's heads and that Americans must first learn the psychology of poor people."),
  ("frus1958-60v16","d65",A+"NSC 6012, July 1960. A policy line to keep the number of American officials to a minimum is justified by the expected reaction to Americans in privileged positions. It is a belief about the audience built into policy."),
  ("frus1917-72PubDipv07","d32",A+"Tull's field review of USIS Vietnam, October 1964. It states plainly what the reviewer thinks of the Vietnamese civil population and why American messages must travel through Vietnamese hands."),
  ("frus1964-68v29p2","d46",A+"Ambassador Reischauer to Bundy, May 1965. It explains Japanese hostility to the bombing of North Vietnam by pacifism, leftist intellectuals and racial closeness to the victims, and gives the one poll he had.")]),
("How effective officials thought it was",
 "These six documents are the assessments of effect, in order of date. The thread runs from counts of material placed in 1955 and 1957, to flat doubt in 1964 that any program could outrun events, to the first attempts to ask the audience in 1966 and 1970.",
 [("frus1955-57v09","d190",A+"National Security Council report of August 1955 on the foreign information program. The Far East section reports activity and placements, and concedes a press unreceptive to explanatory material."),
  ("frus1955-57v09","d207",A+"The same series, September 1957. The Far East section is again a country-by-country account of activity, with a hedge on Japan: a favourable public attitude beside rising dissatisfaction."),
  ("frus1964-68v01","d197",A+"Rowan to President Johnson, June 4, 1964, reporting the Honolulu working group. It says no information program can turn defeats into victories, and cites film audiences as the available measure."),
  ("frus1917-72PubDipv07","d73",A+"Moore to Marks, January 1966, summarising Far East posts. It describes programs aimed at elites and budgets too small for mass efforts."),
  ("frus1917-72PubDipv07","d100",A+"Marks to Rostow, August 1966, with the agency's survey of how the world saw Vietnam. It lists the images that hurt and the means posts judged effective, including Asian voices."),
  ("frus1917-72PubDipv08","d88",A+"Oleksiw to Shakespeare, June 1970: results of the May opinion survey in Saigon, 637 adults, including the lowest rating yet of the US as a dependable ally.")]),
("The image followed policy and America at home",
 "Three documents from 1968 to 1971 show officials concluding that the regional image of the United States moved with the state of the alliance and with American domestic order, more than with anything the information program produced.",
 [("frus1964-68v29p2","d123",A+"Embassy Tokyo, June 5, 1968: Tet, racial violence and unrest at home are read as unsettling Japan's view of the United States."),
  ("frus1917-72PubDipv08","d31",A+"Summary of the East Asia and Pacific public affairs officers' conference, Manila, May 1969. It records that Asians watch America, that prestige falls with domestic troubles, and that the image depends more on bilateral issues."),
  ("frus1917-72PubDipv08","d149",A+"Southard, November 1971, on overseas Chinese attitudes after the opening to China began. It reads an audience whose pull toward China is emotional and not ideological.")]),
("After Vietnam: reassurance as the message",
 "These seven documents, from 1974 to 1978, show the message becoming reassurance that the United States would stay in the region, with posts reporting that audiences doubted it. Two were found through a vector search on a document of 1975 and were not among the top text-query results I read.",
 [("frus1969-76ve12","d10",A+"Smyser to Kissinger, July 1974: Asian countries are judged to be adjusting well to the Nixon Doctrine. Reached through the semantic neighbours of the 1975 USIA reassessment."),
  ("frus1969-76v38p2","d105",A+"Payeff to Keogh and Kopp, May 1975: post-by-post abstracts of public opinion and program implications after the fall of South Vietnam."),
  ("frus1977-80v22","d104",A+"Sullivan, Hong Kong, February 1977: the Asian reading of Washington's refusal to reassess after 1975. Reached through the semantic neighbours of the 1975 USIA reassessment."),
  ("frus1977-80v30","d79",A+"Smith to Bray, July 1977: the agency is told the Administration believes it must shore up East Asian confidence in American staying power."),
  ("frus1977-80v30","d81",A+"Holbrooke's telegram (signed Vance) to chiefs of mission, July 1977, asking for views on public diplomacy in Asia and telling posts that country plans will be re-read against policy goals."),
  ("frus1977-80v30","d83",A+"Embassy Jakarta's reply, August 1977: public diplomacy is judged effective, but the audience still believes the US is withdrawing and finds the human rights message accusatory."),
  ("frus1977-80v30","d152",A+"Mort Smith, Beijing, October 1978, on exchanges and other programs of the International Communication Agency in the PRC. It is the one document here in which the audience is being opened and not reassured.")]),
]
INTRO=("What FRUS answers directly: the series never uses the phrase soft power, but 25 documents from 1949 to 1978 show how the officials who ran American information work in East Asia and the Pacific described their message (contrast with communism, American strength, and after 1975 reassurance), their belief about the audience (nationalist, poor, wary of whites, persuaded by its own people, America-watching) and their judgement of effect (counts of output in the 1950s, doubt in the 1960s, surveys that moved with policy). "
"Where FRUS points for the rest: the printed documents mostly came from the records of the U.S. Information Agency in Record Group 306 at the National Archives and from presidential libraries; the footnotes of the regional volumes cite unprinted State Department lot files and central files and presidential library files, kept as a separate channel. "
"What this request cannot get from FRUS: any source that uses the term soft power, the audience's own voice, controlled measures of effect, or the private and cultural channels beyond the government; the Agency's own research reports are in the National Archives.")
entries=[]; seen=set(); allpairs=[]
for head,prose,docs in SECTIONS:
    entries.append({"kind":"heading","text":head,"level":1})
    entries.append({"kind":"prose","text":prose})
    for v,d,note in docs:
        assert (v,d) not in seen; seen.add((v,d)); allpairs.append((v,d))
        assert db.execute("SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone(), (v,d)
        assert not v.endswith("Ed2")
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[note]})
        for t in EX[(v,d)]:
            entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":t})
entries.append({"kind":"heading","text":"Threads not followed","level":1})
entries.append({"kind":"prose","text":"Not followed: the Philippines and Indonesia as audiences (only passing documents were read); Korea after 1960; the Voice of America's audience in China; Australia and New Zealand; the cultural and educational exchange record (Fulbright appears in the regional volumes, but most hits are the Senator); the pre-1948 China volumes; and the Agency's own research reports, which are summarised in these documents but not printed. Most semantic neighbours of documents in the collection were listed and not read."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
doc={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,"name":"Soft power in East Asia and the Pacific (agent run f11)","authorLine":"Agent run f11, 2026-10-31","introductionText":INTRO,
"composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},"entries":entries}
json.dump(doc,open("collection.fruscollection","w"),ensure_ascii=False,indent=1)
nd=sum(1 for e in entries if e["kind"]=="document"); ne=sum(1 for e in entries if e["kind"]=="excerpt")
print("documents",nd,"excerpts",ne,"unique pairs",len(seen),"all pairs exist in document_cache: yes (asserted)")
miss=[k for k in EX if k not in seen]; print("excerpt docs not in collection:",miss)
