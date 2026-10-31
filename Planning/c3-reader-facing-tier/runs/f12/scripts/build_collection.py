# builds collection.fruscollection; verifies every pair against document_cache (SQL below) and every excerpt as exact substring of body_text
# SQL: SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0
import json,sqlite3
R="/Users/jbotts/frus-analysis/c3f/runs/f12"
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
A="Agent finding, run f12, 2026-10-31: "
quotes=json.load(open(R+"/quotes.json"))
Q={}
for v,d,t in quotes: Q.setdefault((v,d),[]).append(t)
F=[
("Information as anti-communist psychological strategy, routed through local voices (1950–1957)",
 "The earliest planning treated the information program as one arm of a psychological strategy against communist expansion in Southeast Asia: produce in local languages, place material in the local press, aim at leaders, and let Asian governments speak. These documents show how officials measured success (placement, attendance, demand for English) and the limits they set themselves (French and British sensitivities, the fear of looking colonial).",
 [("frus1950v06","d31","The Bureau of Far Eastern Affairs reports the expanded information program in Southeast Asia and offers the first evidence of effect: more U.S. material appearing in the local press."),
  ("frus1952-54v13p1","d116","Ambassador Heath's survey for a Senate inquiry: objectives in Indochina, which devices worked, and why rural audiences were not a primary target. Reached through a semantic-neighbour search, not a word search."),
  ("frus1952-54v12p2","d403","The Psychological Strategy Board's plan based on Thailand: work through indigenous leadership and local outlets, and treat each Southeast Asian nation as a separate audience."),
  ("frus1952-54v12p2","d405","The country team's appraisal in Bangkok: the 'will to resist' is the psychological objective, and the Thai government should run the program."),
  ("frus1952-54v12p2","d407","The USIS part of the Bangkok recommendations: themes chosen for a Thai audience (monarchy, religion, independence)."),
  ("frus1955-57v22","d447","USIA's objection to expanding its Malaya program, in part from fear of appearing to support colonialism, overruled by the Far Eastern bureau.")]),
("The image to project: strength, reliability and modest openness (1962–1969)",
 "From the early 1960s the regional office stated a single image (American strength, reliability and friendship), aimed it at elites, and judged its success by personal contact and by the state of each bilateral relationship. These documents carry the officials' clearest statements about what Asian audiences valued and what put them off.",
 [("frus1961-63v23","d289","USIA's plan for Indonesia: youth, American studies, travel, and a warning to respect neutrality and avoid 'glamorous' quick-impact gestures."),
  ("frus1917-72PubDipv06","d127","Ambassador Reischauer judges John Glenn's 1963 visit the most successful American visit to Japan from a public-image standpoint, and says why."),
  ("frus1917-72PubDipv07","d73","The Far East area office summarises its posts: the image of strength, reliability and friendship is basic; elites are the target almost everywhere."),
  ("frus1917-72PubDipv08","d31","The 1969 Manila conference of public affairs officers: Asians as 'America watchers', the image of the U.S. driven by bilateral relations, and low U.S. visibility.")]),
("Counterinsurgency information in Indochina and Thailand: a surrogate voice meant to become local (1964–1970)",
 "Where there was insurgency the programme stopped addressing elites and became a surrogate information service for the host government. Officials judged it by whether local services could take it over and, by 1970, by opinion surveys; their beliefs about the audience were at their bluntest here.",
 [("frus1917-72PubDipv07","d32","A 1964 field review of USIS Vietnam: peasants will be persuaded by other Vietnamese, motivation is the 'number one problem', with a harsh view of the civil population."),
  ("frus1964-68v27","d386","USIA's director asks that the Thai government build its own national information program and court foreign correspondents."),
  ("frus1917-72PubDipv07","d171","Educational television for Vietnam is to be kept apart from USIA so that it is not seen as propaganda."),
  ("frus1917-72PubDipv08","d58","The handover of information and psychological operations in Vietnam: USIA saw its role as short-term from the start."),
  ("frus1917-72PubDipv08","d88","A Saigon opinion survey of May 1970: the rating of the U.S. as a dependable ally at its lowest in thirteen surveys."),
  ("frus1917-72PubDipv08","d92","Notes on Cambodia's 'communications vacuum': keep the American presence small and let Cambodians do as much as possible.")]),
("Where the audience pushed back: Indonesia, Japan, China and the overseas Chinese (1965–1971)",
 "These documents record the limits of persuasion as officials saw them: mob attacks on USIS posts, Japanese strains measured in opinion surveys, a USIA film held back so as not to offend Peking, and an audience (the overseas Chinese) proud of China and wary of both camps.",
 [("frus1964-68v26","d106","USIA's director calls attacks on USIS in Indonesia 'intolerable' and proposes retaliation; the editors' note records a White House aide's view that this was an over-reaction."),
  ("frus1969-76v19p2","d67","USIA's director asks for an NSC review of Japan policy, citing opinion surveys that confirm strains."),
  ("frus1917-72PubDipv08","d143","The East Asia bureau asks USIA not to release a film on Tibet during the opening to China."),
  ("frus1917-72PubDipv08","d146","USIA's East Asia office proposes 'Psychological Initiatives' for the President's trip to Peking: moon rocks, an astronaut, books."),
  ("frus1917-72PubDipv08","d149","A survey of public affairs officers on overseas Chinese attitudes in Southeast Asia after the thaw.")]),
("After Saigon: credibility as the message (1975–1977)",
 "After 1975 the officials' assessment turned on one question, whether Asians still believed the United States would stay. Post-by-post reassessments, the Carter administration's call for public diplomacy in Asia, and the Jakarta embassy's reply show what they thought the region's audiences doubted.",
 [("frus1969-76v38p2","d105","Post-by-post reassessment after the fall of South Vietnam: Japan, Korea, Thailand, the Philippines, Indonesia, Singapore, Malaysia, Hong Kong, Taiwan, Burma, Laos, Australia, New Zealand."),
  ("frus1977-80v30","d2","USIS Tokyo and Brussels build exchanges among economic editors: 'gut issues' rather than cultural exchange."),
  ("frus1977-80v30","d79","USIA's East Asia director: shoring up East Asian confidence in American staying power is real policy."),
  ("frus1977-80v30","d81","Assistant Secretary Holbrooke asks chiefs of mission in East Asia for views on public diplomacy in support of policy (the request Jakarta answered)."),
  ("frus1977-80v30","d83","The Jakarta embassy's answer: public diplomacy effective, but a persistent belief that the U.S. is withdrawing, and a human-rights message heard as accusatory.")]),
]
date={}
for v,d,t in [(x[0],x[1],None) for f in F for x in f[2]]:
    r=c.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?",(v,d)).fetchone(); date[(v,d)]=r[0] if r else "9999"
entries=[]; seen=set(); nexc=0
for title,prose,docs in F:
    entries.append({"kind":"heading","text":title,"level":1})
    entries.append({"kind":"prose","text":prose})
    for v,d,note in sorted(docs,key=lambda x:date[(x[0],x[1])]):
        assert (v,d) not in seen; seen.add((v,d)); assert not v.endswith("Ed2")
        body=c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,d)).fetchone()
        assert body, (v,d)
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]})
        for t in Q.get((v,d),[]):
            assert t in body[0],(v,d,t); entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":t}); nexc+=1
entries.append({"kind":"prose","text":"Threads this run could not follow: (1) the opinion-survey reports themselves (USIA's research office); FRUS prints summaries of a few, not the surveys; (2) the audiences' own voices, since FRUS prints U.S. records only; (3) 1981 onward, for which no East Asia or public diplomacy volume is in this corpus; (4) Burma, Korea, Australia and New Zealand, which appear mainly inside regional round-ups; (5) Voice of America broadcasting policy toward China and Vietnam, which this run did not separate out; (6) 1956–1961, a gap between the Malaya staff study and the Kennedy-era documents that the chosen searches did not fill."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
intro=open(R+"/intro.txt").read().strip()
coll={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"American soft power in East Asia and the Pacific: how officials judged it, 1950–1977",
 "authorLine":"Agent run f12, 2026-10-31",
 "introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":entries}
json.dump(coll,open(R+"/collection.fruscollection","w"),ensure_ascii=False,indent=1)
print("documents",len(seen),"excerpts",nexc,"entries",len(entries))
open(R+"/out/collection_pairs.txt","w").write("\n".join(f"{v} {d}" for v,d in sorted(seen)))
