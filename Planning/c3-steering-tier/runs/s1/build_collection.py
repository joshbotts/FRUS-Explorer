import json, sqlite3, re
from quotes import Q
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
STAMP="Agent run s1, 2026-10-30: "
qd={q[0]:q for q in Q}
# used excerpts (the quotations the overview relies on)
USED=["Q01","Q03","Q04","Q06","Q07","Q08","Q10","Q13","Q14","Q15","Q17","Q18","Q19","Q20","Q24","Q25","Q26"]
by_doc={}
for q in USED: by_doc.setdefault((qd[q][1],qd[q][2]),[]).append(qd[q][3])
def doc(v,d,note): return ("doc",v,d,note)
sections=[
("Corruption as the reason to press a client for reform: the Philippines and Haiti",
 "These four documents show Washington naming corruption to the governments it was aiding and asking for administrative and fiscal change in return. The thread runs from the 1950 survey mission to Manila, through a 1961 conversation about President Garcia, to a 1978 aid proposal for Haiti that two departing officers thought would fail. They are here because each records what Americans said to the client or proposed to do about it, not only that they thought the government corrupt.",
 [doc("frus1950v06","d832","The survey mission's chief reports telling President Quirino that graft and corruption met the mission everywhere. The mission's remedies, in the document, are about budgets, taxes and government corporations, so corruption is the symptom Washington names and fiscal reform the price it names."),
  doc("frus1950v06","d841","The mission's report to the President lists inefficiency and even corruption as widespread, then recommends tax, fiscal and administrative measures. Read with the conversation of 21 August, it shows the corruption charge folded into an economic programme."),
  doc("frus1961-63v23","d356","Former Ambassador Cowen describes telling President Garcia plainly that graft and corruption in his administration explained his low standing. The editors' headnote records that Deputy Under Secretary Johnson then asked Cowen for advice."),
  doc("frus1961-63v23","d358","Johnson tells a Philippine visitor that high-level U.S. officials are concerned about corruption, that the Philippines could not lead in Asia without change, and that outside experts, not Americans, should be placed in ministries. Washington's chosen instrument is persuasion plus an international adviser."),
  doc("frus1977-80v23","d252","Two departing embassy officers say the May 1978 PL-480 proposal for Haiti strikes at institutionalised corruption on which Duvalierist power rests, and doubt it will work. A dissenting view, not the embassy's policy."),
 ]),
("Vietnam: corruption as a political problem the United States would not take over",
 "From 1960 to 1970 American officials in Saigon and Washington treated corruption in South Vietnam as an obstacle to the war, a vulnerability with Congress and the press, and a subject for quiet talks with Diem, Thieu and their ministers. These documents also show the limit Washington set itself: the Embassy declined the vetoes that would have been needed to end it.",
 [doc("frus1958-60v01","d111","Ambassador Durbrow reports Presidential adviser Ladejinsky's conversations: Diem's own staff and ministers are worried about corruption in the Can Lao Party. An early case of the Embassy hearing the charge from inside Diem's circle."),
  doc("frus1958-60v01","d135","Secretary Herter's cable of April 1960 records Assistant Secretary Parsons raising corruption and relations with the people with Finance Secretary Thuan, and urging him to talk frankly with Durbrow."),
  doc("frus1964-68v05","d197","McPherson reports to President Johnson on a Vietnam trip: Thieu concedes most generals and senior provincial officials are corrupt and says people can live with some of it; McPherson answers that loyalty to the national government is not there to absorb it."),
  doc("frus1964-68v05","d258","Minister-Counselor Calhoun, answering Komer's proposal to blacklist officials, agrees corruption is a key obstacle to pacification but declines the American veto over appointments that would be needed to end it, as an invasion of sovereignty."),
  doc("frus1964-68v05","d395","Katzenbach tells President Johnson that the group of senior officials agreed unanimously a visible, credible anti-corruption effort would improve the Administration's position as well as the Saigon government."),
  doc("frus1917-72PubDipv07","d177","The public line sent to every post after Senator Kennedy's January 1968 criticism: Vice President Humphrey says corruption is no monopoly of Southeast Asia. Shows allegations of corruption handled as a public-diplomacy problem."),
  doc("frus1964-68v07","d91","Bunker's weekly message to President Johnson credits the Thieu-Huong government with cutting corruption back while calling it a deep-rooted cancer."),
  doc("frus1969-76v06","d175","Bunker tells Thieu that corruption is the number one problem and a problem of Vietnamese-American relations; he ties it to the McClellan Committee hearings, congressional mood and further assistance. The editors record that Nixon had asked for quiet work on it."),
 ]),
("Corruption as a threat to a friendly regime's stability",
 "Here the embassies write about corruption in countries whose governments Washington wanted to keep. The argument is about stability and U.S. interests, and it comes with open doubt about what the United States could do. The documents run from the Moroccan coup attempt of 1971 to the Saudi ambassador's appraisal of 1980.",
 [doc("frus1969-76ve05p2","d119","After the July 1971 coup attempt the Embassy in Rabat weighs corruption against the King's lifestyle as explanations for it, calling corruption a popular issue; one informant is bothered more by the King's way of living."),
  doc("frus1969-76v27","d45","Ambassador Helms reports the Shah's decree on corruption and his remark that he may have been too tough; Helms replies that he cannot be too tough. Shows an ambassador encouraging a client's anti-corruption campaign because of the regime's future."),
  doc("frus1969-76ve09p2","d122","The Jidda Embassy's airgram assesses corruption in Saudi Arabia: it grew, it endangers the dynasty over three to five years, and the Embassy proposes only limited action 'not from any moralistic concern'. The fullest assessment in the volumes searched."),
  doc("frus1977-80v18","d206","Ambassador West lists corruption 'in the Western sense' among four threats to the royal family and the special relationship, and says he knows of no truly effective way for the United States to correct it."),
 ]),
("When the bribes were American: disclosure, protection and a new rule",
 "From 1975 the question was often not what a foreign government was taking but what U.S. firms had paid. These documents show the Department refusing to cover for a company, Ambassadors reassuring princes whose names might come out, the President agreeing to share Securities and Exchange Commission material with Japan, and the arrival of an international and a domestic rule against foreign bribery.",
 [doc("frus1969-76ve11p1","d159","Assistant Secretary Rogers tells Kissinger that United Brands paid a bribe to the Honduran Chief of State and that the Department refused the company's requests to intercede with the SEC or the Honduran government."),
  doc("frus1969-76ve09p2","d161","Ambassador Akins tells Defense Minister Sultan that Lockheed has admitted bribes and that Senate committees want the names; Sultan demands the names never be revealed and hints at a turn to the Soviets. The Department and Lockheed were 'standing firm' against disclosure."),
  doc("frus1969-76ve15p2","d292","Hartman relays what a Senate Subcommittee staffer says about Lockheed payments in Western Europe. A report of a staff investigator's claims, not an established fact."),
  doc("frus1969-76ve12","d218","Japanese Prime Minister Miki asks President Ford for the names of Japanese officials in the Lockheed record, arguing that Japanese democracy is at stake."),
  doc("frus1969-76ve12","d219","Ford replies that the SEC's information will be shared with Japanese law enforcement, within U.S. law, and welcomes new rules on corrupt practices. The Japanese cabinet accepted on 12 March, per the editors."),
  doc("frus1969-76ve12","d224","Kissinger tells Japan's special envoy that the Secretary of State cannot interfere in the SEC and Justice investigations although he hopes to avoid foreign-policy embarrassment."),
  doc("frus1969-76v31","d149","At the Puerto Rico summit Ford announces disclosure legislation and asks the leaders to support an international agreement against bribery; Prime Minister Trudeau supports it and asks whether it can work."),
  doc("frus1977-80v03","d248","Commerce and the Trade Representative tell President Carter that exporters rank the Foreign Corrupt Practices Act second among export disincentives; they say the prohibition was intended and ask for clarifying amendments."),
 ]),
("Corruption charges as grounds for trusting or distrusting a government",
 "These four documents show American diplomats using a charge of corruption to account for why a government would or would not hold and what Washington should do. In China in 1943-44 it explained the Nationalists' weakness; in Korea in 1961 the Embassy's account of a campaign against graft supported accepting the new military government.",
 [doc("frus1943China","d202","Davies diagnoses the Nationalist government as riddled with nepotism, graft and bribery and recommends a consulate general and military observers in Communist territory as preliminary action."),
  doc("frus1944v06","d269","Ambassador Gauss reports a plot by young Chinese officers to remove officials they believed corrupt and inefficient, and its reported suppression."),
  doc("frus1961-63v22","d244","The Embassy's joint country-team telegram treats the military government's campaign against graft, bribery and corruption as genuine, while warning of signs of corruption returning."),
  doc("frus1961-63v22","d249","Ambassador Berger tells Rusk that Park's government will not tolerate corruption and graft and that false rumours of corruption have almost ceased; he nonetheless reports confirmed cases among officers."),
 ]),
]
entries=[]
seen=set()
for title,prose,docs in sections:
    entries.append({"kind":"heading","text":title,"level":1})
    entries.append({"kind":"prose","text":prose})
    for _,v,d,note in docs:
        assert (v,d) not in seen; seen.add((v,d))
        r=con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,d)).fetchone()
        assert r, (v,d)
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[STAMP+note]})
        for t in by_doc.get((v,d),[]):
            assert re.sub(r"\s+"," ",t) in re.sub(r"\s+"," ",r[0]), (v,d,t[:40])
            entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":t})
entries.append({"kind":"heading","text":"Threads this run could not follow","level":1})
entries.append({"kind":"prose","text":"Not followed: corruption before 1940 beyond a handful of readings (the 1893 Hawaii inquiry, a bribery case in the Ottoman Empire in 1893-94, extradition and treaty clauses on bribery), the Chinese civil war of 1945-49, Iran in the 1950s, the Dominican Republic in 1964, Indonesia, Japan's wider Lockheed record, and the 1982 intelligence report on corruption in the Soviet elite. Nor do these volumes hold the Senate hearings that exposed the American payments, the text and enforcement history of the Foreign Corrupt Practices Act, or evidence on whether any charge was true. Whether corruption changed a decision, as against decorating an argument already made, is a judgement the documents only sometimes allow."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
coll={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"Corruption and U.S. foreign policy, run s1",
 "authorLine":"Agent run s1, 2026-10-30",
 "introductionText":"What FRUS answers directly: American diplomats and officials wrote about corruption abroad, and about American payments abroad, in about two thousand documents, and in the thirty or so cited here it can be seen being used in a decision or in the conduct of diplomacy: as a ground for pressing clients for reform in the Philippines and Haiti, as a problem for the Vietnam war the United States chose not to take over, as a threat to regimes it wanted to keep in Iran and Saudi Arabia, as a matter of disclosure when American firms had paid the bribes, and as a reason for trusting or distrusting governments in China and Korea. Where FRUS points for the rest: the printed documents came from the State Department's central files (decimal, subject-numeric and foreign policy files), an embassy lot at Jidda, and the Johnson, Nixon, Ford and Carter presidential libraries; the editors cite unprinted material in State Department lot files such as the Far Eastern Bureau and Saigon Embassy files, and in the same libraries. What this request cannot get from FRUS: any count of how often corruption changed a decision, whether the charges were true, the Senate hearings and the Foreign Corrupt Practices Act's own history, and a settled account before 1940.",
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":entries}
json.dump(coll,open("collection.fruscollection","w"),ensure_ascii=False,indent=2)
docs_n=[e for e in entries if e["kind"]=="document"]; ex=[e for e in entries if e["kind"]=="excerpt"]
print("documents",len(docs_n),"excerpts",len(ex),"entries",len(entries))
