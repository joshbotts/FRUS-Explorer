# make_collection.py: writes collection.fruscollection from raw/quotes.json and the notes below; checks pairs against document_cache
import json,sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
Q={q[0]:q for q in json.load(open('raw/quotes.json'))}
A="Agent finding, run f3, 2026-10-31: "
sections=[
("1. The program as alignment with Asian nationalism, and early doubts (1949–1957)",
 "Why these documents: they set out what the information program in Asia was for and how its first managers judged it. The thread runs from Jessup's call for an expanded program in 1949, through the Psychological Strategy Board's country-by-country plan and Saigon's 1952 effectiveness report, to the National Security Council's candid annual reports of 1955 and 1957.",
 [("frus1949v07p2","d386","Proposes an expanded information program in Asia to identify the United States with Asian nationalism and against Soviet imperialism.",["Q1"]),
  ("frus1952-54v13p1","d116","Saigon's reply to the 1952 circular on program effectiveness: reach among educated groups read as success; the rural majority admitted to be outside the program. Reached through a document-similarity neighbour of the 1969 Manila conference summary, then read.",["Q2","Q3"]),
  ("frus1952-54v12p2","d403","Psychological Strategy Board plan for Thailand: psychological operations through indigenous channels, and the premise that each Southeast Asian nation needs separate treatment.",["Q6"]),
  ("frus1955-57v09","d190","1955 report to the NSC: the Formosa Strait crisis forced the agency to answer fears of atomic weapons used against Asians and racial propaganda; aims to orient Asian neutralists and strengthen allies.",["Q4"]),
  ("frus1955-57v09","d207","1957 report to the NSC: country-by-country Far East programs and the admission that accommodation to Communist pressure continued despite them.",["Q5"])]),
("2. Beliefs about the audience: 'the Oriental mind'",
 "Why these documents: each ties a belief about how Asians think to a recommendation on how the United States should present itself — aid as weakness, doubts about American staying power, aid not understood as altruism — and the last two show Diem's government turning the same idea against the Americans.",
 [("frus1952-54v14p2","d551","Ridgway from Tokyo: American interest in Asia must be shown to be permanent, by word and deed.",["Q8"]),
  ("frus1952-54v12p2","d60","Sebald from Rangoon: Burmese cannot read aid as altruism; recommends withdrawing from the local limelight.",["Q9"]),
  ("frus1952-54v13p2","d992","McClintock from Saigon: aid should be strictly reciprocal because give-aways read as weakness; calls for psychological techniques to supply a 'mystique'.",["Q7"]),
  ("frus1958-60v01","d26","Durbrow reports Diem's conviction that Americans cannot understand Asians and that Vietnamese should do the work in the region.",["Q10"]),
  ("frus1961-63v02","d29","Pacific Command's political adviser records the Saigon government's view that American concepts do not fit Asian ways.",["Q11"])]),
("3. Vietnam: information as a weapon of war",
 "Why these documents: they show the information agency inside the Vietnam war — warning of the regional cost of defoliants, designing ridicule of the Viet Cong, and asking that psychological programs rank with military ones.",
 [("frus1961-63v01","d265","The agency's Far East director warns that defoliants will feed 'germ warfare' propaganda across Asia.",["Q12"]),
  ("frus1961-63v02","d197","The Saigon public affairs officer's questions for improving South Vietnamese propaganda: ridicule, face, town versus village.",["Q13"]),
  ("frus1964-68v01","d197","Rowan's 1964 report to the President on a public affairs program for South Vietnam, from the Honolulu discussions.",[]),
  ("frus1917-72PubDipv07","d37","Rowan's 1965 report: the psychological program is better than a year earlier but still inadequate; asks equal status with military and economic operations.",["Q14"])]),
("4. Japan and the region's elites: contact, achievement, and the limits set by policy",
 "Why these documents: they trace the elite-centred model in Japan and across the area — vigorous programs against neutralism, the Glenn visit as the model success, Reischauer's verdict that policy outweighed persuasion in 1965, and the 1966 and 1969 area reviews.",
 [("frus1952-54v14p2","d820","1954 progress report on Japan policy: vigorous information programs alongside rising neutralism and anti-Americanism.",["Q16","Q30"]),
  ("frus1917-72PubDipv06","d127","Reischauer on John Glenn's 1963 visit as the most successful image event since Robert Kennedy's.",["Q17"]),
  ("frus1964-68v29p2","d46","Reischauer on Japanese reaction to the bombing of North Vietnam: some intellectual success, emotional response unchanged; poll figures cited.",["Q18","Q19"]),
  ("frus1917-72PubDipv07","d73","Far East area office summary of post reports, 1966: elite targets, image of strength and reliability, personal contact as the most effective medium.",["Q20","Q21"]),
  ("frus1917-72PubDipv08","d31","Summary of the 1969 Manila conference of public affairs officers: attitudes toward America, low US visibility, Japan's image in Southeast Asia.",["Q23","Q22","Q24"])]),
("5. Credibility after the China opening and the fall of Saigon (1971–1977)",
 "Why these documents: they show the agency recasting its aims around credibility — exploiting the Peking trip, studying the overseas Chinese, collecting post reassessments after 1975, and shifting Japan work to economic communication.",
 [("frus1917-72PubDipv08","d146","Proposals to turn the President's China trip into a lasting psychological asset (moon rock, astronaut, books).",["Q25"]),
  ("frus1917-72PubDipv08","d149","Report on overseas Chinese attitudes in Southeast Asia after the thaw with Peking.",["Q26"]),
  ("frus1969-76v38p2","d105","Abstracts of East Asia posts' reassessments after the fall of South Vietnam, country by country.",["Q27","Q28"]),
  ("frus1977-80v30","d2","USIS Tokyo and Brussels initiatives for US–EC–Japan media exchanges on trade issues.",["Q29"])])]
intro=open('raw/intro.txt').read().strip()
entries=[]; seen=set()
for title,prose,docs in sections:
    entries.append({"kind":"heading","text":title,"level":1}); entries.append({"kind":"prose","text":prose})
    for v,d,note,qs in docs:
        assert con.execute("SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,d)).fetchone(), (v,d)
        assert (v,d) not in seen; seen.add((v,d)); assert not v.endswith('Ed2')
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]})
        for q in qs:
            _,qv,qd,text=Q[q]; assert (qv,qd)==(v,d)
            assert con.execute("SELECT instr(body_text,?) FROM document_cache WHERE volume_id=? AND document_id=?",(text,v,d)).fetchone()[0]>0
            entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":text})
entries.append({"kind":"heading","text":"Threads not followed","level":1})
entries.append({"kind":"prose","text":"Threads this run could not follow: (1) the other embassies' 1952 replies to the Department's circular on information-program effectiveness, of which FRUS prints only Saigon's — they sit in the State Department's 1950–54 decimal file, class 511; (2) the Information Agency's own measures — country plans, opinion surveys, the full sixty-page report of the 1969 Manila conference, and the 1975 post cables printed only as abstracts — in Record Group 306, which the bundled finding aids reach only at the level of accessions split across many series; (3) Korea, the Philippines, Indonesia, Australia and New Zealand, sampled here only through regional reports; (4) the 1981–1988 volumes."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
doc={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"Information programs and the American image in East Asia, 1949–1977",
 "authorLine":"Agent run f3, 2026-10-31",
 "introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":entries}
json.dump(doc,open('collection.fruscollection','w'),ensure_ascii=False,indent=1)
print('documents',sum(e['kind']=='document' for e in entries),'excerpts',sum(e['kind']=='excerpt' for e in entries),'entries',len(entries))
