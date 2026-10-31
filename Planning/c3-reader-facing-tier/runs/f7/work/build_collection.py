import sys,json,sqlite3
sys.path.insert(0,"work")
from docs_spec import *
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
meta=json.load(open("work/docmeta.json"))
A="Agent finding, run f7, 2026-10-31: "
INTRO=("What FRUS answers directly: the series never uses the phrase soft power, but its East Asia, Pacific and public-diplomacy volumes hold the officials' own judgments, under the older names information program, psychological strategy and public diplomacy. They show a 1950 programme of local-language material that its own officials called weak and badly aimed; a recurring belief that Asian audiences follow the winner, respect resolve and misread aid as softness; a view that American society and single events drew Asian audiences more than messages did; and, after Vietnam and the China opening, a message of reassurance that posts reported audiences did not credit until policy was clear. "
"Where FRUS points for the rest: the printed documents came mostly from the State Department's central decimal files (Record Group 59) and from the Records of the U.S. Information Agency (Record Groups 306 and 305, Director's Subject Files and Office of Policy and Plans files), with presidential-library series for a few; the editors' footnotes point, unprinted, to State Department lot files and to presidential-library national security files. "
"What this request cannot get from FRUS: independent measurement of how audiences received the messages, the content of the broadcasts, films and publications themselves, the wartime and Japan-occupation information work (not read in this run), and the Asian side of the exchange.")
NOTES={
 ("frus1950v06","d15"):"The Bangkok conference of chiefs of mission (February 1950) concluded that worldwide information material was not satisfactory and asked for material aimed at specific groups in simple language; it also ties U.S. prestige in Asia to showing the American way of life working in Japan, Korea and the Philippines.",
 ("frus1950v06","d31"):"State's Far Eastern public affairs officer reports a stepped-up information programme for Southeast Asia and offers one early sign of effect: more use of the material in local newspapers. A regional production centre at Manila is planned.",
 ("frus1950v06","d32"):"Jessup's report of his 14-nation tour: the United States is 'weak on propaganda', must decide whom it is trying to reach, and faces an Asian audience that French and British officials say waits to see who is winning.",
 ("frus1952-54v12p2","d403"):"The Psychological Strategy Board's Thailand paper: overt information programmes through indigenous outlets, tied to aid, military assistance and guerrilla preparation. Shows 'information' as one arm of a wider psychological strategy.",
 ("frus1952-54v12p2","d359"):"The National Security Council's Philippines paper includes an inventory of what the U.S. information service ran there in 1954 (centres, press, films, radio, exchanges) and the cuts forced by lack of funds.",
 ("frus1950v06","d266"):"A circular from the Secretary of State argues for defending Formosa by appeal to 'the Oriental psychology': Asians respect resolute leadership. A belief about the audience used as policy argument.",
 ("frus1952-54v14p2","d551"):"General Ridgway lists, among what must be done 'by word and deed', overcoming a feeling that U.S. interest in Asia is casual or temporary: the audience belief that U.S. commitment is the message.",
 ("frus1952-54v12p2","d60"):"Ambassador Sebald in Rangoon: the United States was too conspicuous in Burma and could not explain its motives to the Burmese in terms they accepted. Visibility itself damaged the message.",
 ("frus1952-54v13p2","d992"):"The chargé in Saigon argues aid should be on terms of strict reciprocity because give-aways are read in the oriental mind as softness; also asks for psychological techniques to give people an ideal to fight for.",
 ("frus1955-57v22","d361"):"President Magsaysay tells the ambassador that Americans do not understand the Asian mind about gifts to visitors: the audience's own use of the formula, turned on Americans.",
 ("frus1958-60v01","d26"):"The ambassador reports that Diem is convinced Americans, not being Asians, do not understand the Oriental mind. Another case of the formula in an Asian leader's mouth.",
 ("frus1952-54v12p1","d103"):"The consul general in Singapore says anti-colonialism may obscure the meaning of the Laos invasion for Southeast Asians and that Viet Minh nationalism will complicate calling it aggression; he asks for a coordinated 'psychological offensive'.",
 ("frus1955-57v22","d447"):"The Far Eastern bureau records that the information agency objected to expanding its Malaya programme, partly from fear of appearing to support colonialism; State overrode the objection.",
 ("frus1955-57v22","d271"):"The Deputy Under Secretary warns that U.S. support for Dutch trusteeship of New Guinea would be read by Asians as colonialism: the colonial belief used to weigh a policy by its likely reception.",
 ("frus1917-72PubDipv06","d127"):"Ambassador Reischauer judges astronaut John Glenn's 1963 visit to Japan the most successful American visit in public-image terms and compares it with Gagarin's: a single person and programme rated as effective.",
 ("frus1964-68v26","d106"):"USIA Director Rowan reports that Indonesian pressure has left the information service in Indonesia nearly without a programme and asks State for retaliation; the other side of the 'effectiveness' ledger.",
 ("frus1964-68v29p2","d123"):"The Tokyo embassy's 1968 stocktaking of how Japanese see the United States: American institutions, mass culture and way of life remain a positive symbol, but Tet and American racial violence have worn the image.",
 ("frus1917-72PubDipv08","d31"):"Summary of the 1969 Manila conference of USIA public affairs officers for East Asia and the Pacific: Asians watch America, image depends on bilateral issues more than on American domestic news, and PAOs report doubt about U.S. commitment.",
 ("frus1917-72PubDipv07","d147"):"USIA's 1967 policy and research report: in Vietnam, Thailand and Laos the agency was doing tasks that may lie outside its role, absorbing about 15 percent of its overseas programming resources.",
 ("frus1917-72PubDipv08","d24"):"USIA East Asia chief sets 'psychological objectives' for the Midway meeting between Nixon and Thieu as strengthening a public image: message as managed image of a relationship.",
 ("frus1917-72PubDipv08","d58"):"Summary of the plan to hand USIA's Vietnam information and psychological operations to the Vietnamese government: television, radio, printing, leaflets, province staff.",
 ("frus1917-72PubDipv08","d88"):"The agency's own Saigon opinion survey (637 interviews, May 1970): confidence in the U.S. as a dependable ally at the lowest point in thirteen surveys.",
 ("frus1917-72PubDipv08","d92"):"USIA's account of the information vacuum in Cambodia after the 1970 coup and of Communist radio and psywar reach; proposals to lend transmitters.",
 ("frus1917-72PubDipv08","d129"):"USIA reports on Senator Church's bill, quoting his charge that the agency was selling the Thieu government to the Vietnamese public, and lists the agency's surrogate information work in Vietnam, Laos, Thailand and Korea.",
 ("frus1917-72PubDipv08","d30"):"The agency's August 1969 guidance to its media after the Nixon party's Asia stop: Asian initiative and regional arrangements as the line.",
 ("frus1917-72PubDipv08","d127"):"USIA East Asia deputy says the Communists are more alert to cultural approaches and the agency is a decade or a generation behind in audio-visual technique.",
 ("frus1917-72PubDipv08","d143"):"State objects to releasing a USIA film on Tibet because it would send the wrong signal to Peking before the President's visit: messaging constrained by diplomacy.",
 ("frus1917-72PubDipv08","d146"):"USIA proposals for Nixon's trip to Peking (moon rocks, an astronaut, books, a hot line) to turn a 'temporary psychological asset' into a lasting one.",
 ("frus1917-72PubDipv08","d149"):"USIA collects posts' reports on overseas Chinese attitudes after the China opening: proud of Peking, reluctant to accept its models; treated as a USIS audience.",
 ("frus1969-76v38p2","d105"):"After the fall of South Vietnam (May 1975) USIA's East Asia office abstracts posts' reassessments: audiences across the region doubt U.S. staying power; posts ask for clarity of policy before programmes on security.",
 ("frus1977-80v30","d79"):"USIA's East Asia chief points to Secretary Vance's Asia Society speech and State's own submission as showing the policy to be shoring up East Asian confidence in U.S. staying power.",
 ("frus1977-80v30","d81"):"Holbrooke asks chiefs of mission for comments on the future role of public diplomacy in Asia and tells them USIA posts will tighten country plans against U.S. foreign policy goals.",
 ("frus1977-80v30","d83"):"Jakarta's reply: public diplomacy of the new administration has been effective, but the belief that the U.S. is withdrawing from East Asia persists, and the human-rights message is read as accusatory.",
}
PROSE={
 0:"In early 1950 the Department was expanding information work in Southeast Asia while its own officials, back from a regional tour, judged the output weak and aimed at no one in particular. The 1953 and 1954 papers show the same programme as a psychological strategy built round a base country and as a thin, budget-cut inventory of centres, films and radio hours.",
 1:"These documents record what officials believed about the people they were trying to reach: that Asians follow the winner, respect resolve and read aid as softness. Asian leaders turn the same formula back on Americans.",
 2:"The audience was also assumed to carry a colonial memory. These documents show that belief shaping how a message was framed and what the information agency would agree to do.",
 3:"Where officials say the United States was admired, they point to institutions, culture, prosperity and single events. Where they say it slipped, they point to security politics, Tet and American disorder, and in Indonesia to government pressure on the agency itself.",
 4:"Vietnam changed what the information agency was. These documents show a wartime psychological campaign, planners judging parts of it outside the agency's proper role, its own survey measuring falling trust, and Congress attacking it.",
 5:"From 1969 the message is partnership and Asian initiative, then the China opening, then in 1975 and 1977 a repeated discovery that audiences doubted American staying power whatever the programmes said.",
}
CLOSE=("Threads not followed in this run: the wartime Office of War Information material in the 1941-1945 Far East volumes (nine volumes, not read); the Japan occupation's information and education work; Korea's information programme, reached only through two covert rumour documents that were left out; exchange and Fulbright figures by country; South Asia; Australia, New Zealand and the Pacific islands beyond ANZUS; the early 1980s; the content of Voice of America broadcasts, films and publications; and the agency's audience-research reports, which FRUS prints only in fragments. None of these is shown to be absent from the corpus; they were not searched or not read.")
entries=[]
for i,(title,pairs) in enumerate(FINDINGS):
    entries.append({"kind":"heading","text":title,"level":1})
    entries.append({"kind":"prose","text":PROSE[i]})
    for v,d in sorted(pairs,key=lambda p:meta[p[0]+"/"+p[1]]["date"]):
        r=db.execute("select 1 from document_cache where volume_id=? and document_id=? and is_front_matter=0 and is_editorial_note=0",(v,d)).fetchone()
        assert r,(v,d)
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[A+NOTES[(v,d)]]})
        for q in QUOTES.get((v,d),[]):
            entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":q})
entries.append({"kind":"heading","text":"Threads not followed","level":1})
entries.append({"kind":"prose","text":CLOSE})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
doc={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"East Asia and the Pacific: how U.S. officials judged their persuasion, 1950-1977",
 "authorLine":"Agent run f7, 2026-10-31","introductionText":INTRO,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":entries}
json.dump(doc,open("collection.fruscollection","w"),ensure_ascii=False,indent=1)
pairs=[(e["volumeId"],e["documentId"]) for e in entries if e["kind"]=="document"]
assert len(pairs)==len(set(pairs))==33
assert all(e.get("volumeId") and e.get("documentId") for e in entries if e["kind"] in("document","excerpt"))
assert not any(e["volumeId"].endswith("Ed2") for e in entries if "volumeId" in e)
print("entries",len(entries),"documents",len(pairs),"excerpts",sum(e["kind"]=="excerpt" for e in entries))
