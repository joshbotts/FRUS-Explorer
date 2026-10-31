import json,re,sqlite3
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
Q=json.load(open('quotes.json'))
ATTR="Agent finding, FRUS research run, 2026-10-31: "
ov=open('overview.md').read()
def part(n):
    m=re.search(r'\*\*%d\. [^*]+\*\*(.*?)(?=\n\*\*%d\.|\n\*\*Scope)'%(n,n+1),ov,re.S); return ' '.join(m.group(1).split())
intro=("What FRUS answers directly: "+part(1)+"\n\nWhere FRUS points for the rest: "+part(2)+"\n\nWhat this request cannot get from FRUS: "+part(3))
sections=[
("Speaking through Asian voices","These documents show the preferred method from 1949 onward: messages aimed at a target, carried by Asian governments, delegations and media, with the American hand kept out of sight. The thread runs from the China program of 1949 through the Thailand strategy of 1953 and Bandung in 1955 to the handover of Vietnam's psychological operations in 1969.",
 [("frus1949v09","d558","The information program in China is aimed at a political target, a rift between Peking and Moscow, and the Voice of America grows as other channels close."),
  ("frus1952-54v12p2","d396","The departing ambassador in Bangkok credits information programs with some success and asks for Thai-speaking staff to reach the provinces."),
  ("frus1952-54v12p2","d403","The Psychological Strategy Board's plan for Thailand states the rule of working through indigenous leadership and aims at minds and emotions."),
  ("frus1955-57v21","d23","Before Bandung the Department coaches friendly Asian delegations while avoiding any show of American interest."),
  ("frus1917-72PubDipv08","d58","The information agency treats psychological operations in Vietnam as work that belongs to the Vietnamese government and plans its handover.")]),
("Beliefs about the audience","These documents record what officials believed about Asian audiences: nationalism, sensitivity to race and colonial memory, and emotion over argument. Read in date order, they move from Indochina and Japan in the 1950s to Burma, wartime Japan and the overseas Chinese.",
 [("frus1952-54v13p1","d116","Saigon's 1952 assessment of the information program names nationalist and racial feeling as the enemy's lever and counts films, libraries and English classes as evidence."),
  ("frus1952-54v14p2","d762","After the fallout incident of 1954 the embassy in Tokyo describes the Japanese response in terms of national character and emotion."),
  ("frus1955-57v09","d190","The agency's report for 1955 describes Asian emotion over atomic weapons and race, and its programs for Japan, Korea, the Philippines and Taiwan."),
  ("frus1955-57v22","d58","The plan for Burma ties neutralism to colonial memory and warns against patronizing attitudes."),
  ("frus1964-68v29p2","d46","Reischauer's embassy explains Japanese opposition to the bombing of North Vietnam by fear, pacifism and racial sympathy, with poll figures."),
  ("frus1917-72PubDipv08","d149","The agency's posts describe overseas Chinese opinion in Southeast Asia as apolitical, proud of China, and wary of its model.")]),
("Words, deeds and effectiveness","These documents carry the officials' own verdicts on effect. They measured little, judged by attendance and events, and concluded more than once that information could not outrun policy or the war.",
 [("frus1955-57v09","d207","The agency's 1957 report concedes that accommodation to Communist pressure continued in Southeast Asia despite its efforts."),
  ("frus1917-72PubDipv06","d126","The agency fears that rebuttals of Indonesia's anti-American charges will be heard as words without deeds."),
  ("frus1964-68v01","d197","Officials meeting in Honolulu conclude that no information program can make defeats look like victories in Vietnam."),
  ("frus1964-68v02","d160","The agency's director tells the President that efforts to build Vietnamese unity have not progressed to his satisfaction."),
  ("frus1917-72PubDipv08","d31","The agency's East Asian public affairs officers, meeting in Manila, call Asians America watchers, tie America's image to bilateral relations, and drop exposure counts as a measure.")]),
("After Vietnam: credibility of commitment","These documents follow the message after 1975, when posts across the region reported doubt about American staying power and Washington asked what public diplomacy could do about it.",
 [("frus1969-76v38p2","d105","The agency's posts reassess their programs after Saigon falls; post after post reports doubt about American commitment."),
  ("frus1977-80v30","d81","The new Assistant Secretary asks his ambassadors about the future role of public diplomacy in Asia."),
  ("frus1977-80v30","d83","The ambassador in Jakarta reports a persistent belief in American withdrawal and resistance to the human rights message.")]),
("The longer game: students, exchanges, broadcasts","These documents show where officials expected lasting effect: youth, American studies, professional exchanges, and broadcasting once jamming stopped.",
 [("frus1961-63v23","d289","Murrow's plan for Indonesia stresses youth, American studies and respect for neutrality, and warns against quick-impact actions."),
  ("frus1977-80v30","d2","The agency's East Asia office promotes exchanges of economic editors from Japan, Europe and the United States."),
  ("frus1977-80v30","d215","The agency reports Chinese audiences for the Voice of America of over 100 million after jamming stopped in 1977.")]),
]
used_q={i for i in range(1,35)}-{30}
qmap={}
for i,(v,d,q) in enumerate(Q,1):
    if i in used_q: qmap.setdefault((v,d),[]).append(q)
entries=[]; seen=set()
for title,prose,docs in sections:
    entries.append({"kind":"heading","text":title,"level":1})
    entries.append({"kind":"prose","text":prose})
    for v,d,note in docs:
        assert (v,d) not in seen; seen.add((v,d))
        r=c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,d)).fetchone()
        assert r, (v,d)
        assert not v.endswith('Ed2')
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[ATTR+note]})
        for q in qmap.get((v,d),[]):
            assert q in r[0], q
            entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":q})
entries.append({"kind":"heading","text":"Threads not followed","level":1})
entries.append({"kind":"prose","text":"I did not follow several threads. The information agency's own country plans and post reports, where posts recorded what they measured, are not printed here. Military training and aid as influence, such as the Indonesian army's use of American textbooks in 1957, I left outside the question. The Public Diplomacy volume for 1964–1968 I sampled only lightly. Korea and the Philippines appear mainly through the agency's annual reports. Asian voices themselves are absent, since this record reports them only through American eyes."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
col={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"American Voices in Asia: Information Programs, 1949–1980",
 "authorLine":"FRUS research run, 2026-10-31",
 "introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":entries}
json.dump(col,open('collection.fruscollection','w'),ensure_ascii=False,indent=1)
fc=[l.strip() for l in open('final_cited.txt') if l.strip()]
docs=[f"{e['volumeId']}/{e['documentId']}" for e in entries if e['kind']=='document']
print("documents",len(docs),"excerpts",sum(e['kind']=='excerpt' for e in entries),"set equal to final_cited:",set(docs)==set(fc),"dupes:",len(docs)-len(set(docs)))
print("all doc/excerpt entries carry both ids:",all(('volumeId' in e and 'documentId' in e) for e in entries if e['kind'] in('document','excerpt')))
