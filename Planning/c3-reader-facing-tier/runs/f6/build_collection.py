import json,re,sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ex=json.load(open('excerpts.json'))
ov=open('overview.md',encoding='utf8').read().split('## Documents cited')[0]
qs=[re.sub(r'^\[a\] ','a ',q.rstrip(',.')) for q in re.findall(r'["“]([^"”]+)["”]',ov)]
def used(e):
    return any((q in e) or (q[0].upper()+q[1:] in e) for q in qs if len(q)>12)
AT="Agent finding, soft-power run, 2026-10-31: "
notes={
"frus1949v07p2/d386":"The consultants' outline for the President names an expanded information program as one of its specific policies, aimed at showing sympathy for Asian nationalism and exposing Soviet imperialism.",
"frus1950v06/d32":"Jessup's oral report relays the French and British belief that Asians wait to see who is winning, and records where pro-American feeling was strongest. It is the earliest clear statement here of a belief about the Asian audience.",
"frus1952-54v12p2/d403":"A summary of the Psychological Strategy Board's plan for Thailand. It pairs information work with military and economic aid and aims at a climate of victory. Only an extract is printed.",
"frus1952-54v14p2/d820":"The Operations Coordinating Board's first progress report on Japan. It says the committee meant to carry out psychological strategy in Tokyo has been ineffective and blames sensational press reaction for prejudicing relations.",
"frus1961-63v01/d49":"A USIA letter to its Saigon officer ordering a major campaign on Viet Cong insurgency and asking that more material be declassified so it can be used.",
"frus1961-63v01/d265":"USIA's Far East chief warns that defoliants would give communist propaganda an easy theme and could produce ill will across the region.",
"frus1961-63v01/d339":"The public affairs officer in Saigon argues that American information work cannot improve the image of the South Vietnamese government beyond what that government shows the world.",
"frus1961-63v02/d5":"A correspondent's rebuke after an American-only briefing, relayed by USIA, shows how closed briefings damaged credibility with foreign press.",
"frus1917-72PubDipv06/d126":"USIA proposes a campaign against Afro-Asian propaganda led from Indonesia, and judges that it would convince less without a diplomatic protest to back it.",
"frus1917-72PubDipv06/d133":"The State Department declines to publicize its protests to Indonesia, to protect its aid program. The exchange shows messaging being limited by policy goals.",
"frus1961-63v04/d108":"Murrow's survey of world reaction to events in Vietnam: Asian press and officials were largely critical of the Diem regime, with Seoul and Manila the exceptions.",
"frus1964-68v01/d197":"A Honolulu interagency committee's frank view that no information program can disguise military failure, with the figure for Vietnamese film audiences.",
"frus1964-68v02/d160":"The USIA director tells the President that efforts to build unity in South Vietnam have not progressed to his satisfaction, though he claims headway in some areas.",
"frus1964-68v02/d172":"The director sends the President a USIA study of a rural province. It finds a largely apathetic population and names insecurity and weak government, not messaging, as the obstacles. The study itself is not printed.",
"frus1964-68v03/d138":"A White House staff status report says propaganda and psychological operations in South Vietnam had grown more effective with more information personnel.",
"frus1917-72PubDipv07/d171":"USIA's East Asia chief reports plans for educational television in Vietnam. The director acts outside his agency role so that it is not seen as propaganda.",
"frus1961-63v23/d289":"Murrow's plan for USIS in Indonesia: youth, American studies, travel and branch posts, with respect for Indonesia's neutrality and patient persistence.",
"frus1964-68v26/d106":"The USIA director says attacks on USIS in Indonesia are intolerable but that closing the posts would be read as retreat.",
"frus1964-68v27/d386":"Before the Thai prime minister's visit, the USIA director says Thailand lacks a national information program and wants it to take over some programs.",
"frus1917-72PubDipv08/d31":"A summary of the 1969 Manila conference of USIA's public affairs officers in East Asia: Asian audiences watch America, and its image rests on bilateral relations. It also covers books, seminars, binational centers and Japan's image in Southeast Asia.",
"frus1969-76v19p2/d67":"The USIA director asks for a National Security Council review of Japan policy, citing public opinion surveys that confirm strains and posing psychological questions.",
"frus1969-76v38p2/d105":"Abstracts of overseas posts' replies after the fall of South Vietnam: several posts, among them Thailand, Hong Kong, Burma and Taiwan, ask Washington to clarify its policy first, since programs on commitments lack credibility until it does.",
"frus1969-76ve12/d16":"Found by its similarity to the 1975 reassessment, not by word search. Habib's summary of a Southeast Asian tour says assurances are welcomed while doubt rests on Congress.",
"frus1969-76ve12/d17":"Found by its similarity to the 1975 reassessment, not by word search. Smyser describes Asian beliefs about revolutionary warfare and the importance of what America will do.",
"frus1977-80v22/d3":"Found by its similarity to the 1975 reassessment, not by word search. Armacost notes that Asians read American Vietnam policy as a test of broader intentions and expect cycles of involvement and indifference.",
"frus1977-80v30/d79":"USIA's East Asia chief points to the Secretary's Asia Society speech and the Department's budget submission as proof that reassuring East Asians is policy.",
"frus1977-80v30/d81":"A telegram to chiefs of mission in East Asia and the Pacific, sent under Vance's name for Holbrooke, asks them and their public affairs officers to align public diplomacy with policy goals.",
}
sections=[
("Asia as a revolutionary audience, 1949 to 1954","These four documents show how planners first described the Asian audience as a revolution to be won, a public inclined to follow the winner, and a Japanese press to be countered. They follow the thread from the 1949 call for an expanded information program to the 1954 admission that the Tokyo committee was not working.",["frus1949v07p2/d386","frus1950v06/d32","frus1952-54v12p2/d403","frus1952-54v14p2/d820"]),
("Credibility as the working constraint, 1961 to 1963","These documents follow officials who ran the Vietnam and Indonesia campaigns and wrote that the message was limited by the conduct of the government it promoted and by Washington's own press practice.",["frus1961-63v01/d49","frus1961-63v01/d265","frus1961-63v01/d339","frus1961-63v02/d5","frus1917-72PubDipv06/d126","frus1917-72PubDipv06/d133","frus1961-63v04/d108"]),
("Measuring effect in Vietnam, 1964 to 1967","Here the Agency and the White House judge what the information program had achieved in South Vietnam, from a candid view that a message cannot outrun events to a staff claim of improvement and an attempt to keep educational television free of the propaganda label.",["frus1964-68v01/d197","frus1964-68v02/d160","frus1964-68v02/d172","frus1964-68v03/d138","frus1917-72PubDipv07/d171"]),
("Neutral and client governments, 1962 to 1968","These three show the approach to governments that were neutral, hostile or merely under-equipped: carry the message through local institutions, resist leaving under pressure, and press the host to speak for itself.",["frus1961-63v23/d289","frus1964-68v26/d106","frus1964-68v27/d386"]),
("After Vietnam: an audience watching deeds, 1969 to 1977","These documents follow the shift from 'telling America's story' to reassuring Asians of American staying power, and record the belief that Asians judged the United States by its deeds and commitments. Three were found by similarity to the 1975 reassessment rather than by a word search, and read before they were cited.",["frus1969-76v19p2/d67","frus1917-72PubDipv08/d31","frus1969-76v38p2/d105","frus1969-76ve12/d16","frus1969-76ve12/d17","frus1977-80v22/d3","frus1977-80v30/d79","frus1977-80v30/d81"]),
]
# date order within section
def dkey(k):
    v,d=k.split('/'); return con.execute("select date_iso from document_dates where volume_id=? and document_id=?",(v,d)).fetchone()[0]
entries=[]; seen=set()
for title,why,keys in sections:
    keys=sorted(keys,key=dkey)
    entries.append({"kind":"heading","text":title,"level":1})
    entries.append({"kind":"prose","text":why})
    for k in keys:
        v,d=k.split('/')
        assert con.execute("select 1 from document_cache where volume_id=? and document_id=? and is_front_matter=0 and is_editorial_note=0",(v,d)).fetchone(), k
        assert k not in seen; seen.add(k)
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[AT+notes[k]]})
        for ev,ed,et in ex:
            if ev==v and ed==d and used(et):
                entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":et})
entries.append({"kind":"heading","text":"Threads I could not follow","level":1})
entries.append({"kind":"prose","text":"I could not measure the effect of any message on an Asian audience, because the volumes print officials' judgments and almost no survey results. I did not search before 1945, and did not follow aid, the Peace Corps or military assistance as forms of influence. I did not read the Japan and Korea volumes beyond the documents that matched the search terms, so cultural exchange there is thin in this collection. The broadcast scripts, leaflets and films themselves I could not locate in the sources the footnotes cite; the generated list that follows names the series the printed documents came from."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
intro=("What FRUS answers directly: Officials never wrote of soft power; the phrase appears in no volume of the series. They wrote of information programs, psychological strategy and the American image. They planned messages to show sympathy for Asian nationalism and to expose Soviet imperialism, believing that Asians would back whoever seemed to be winning. They judged their own results guardedly, from a Tokyo committee that had not been effective to a director who found efforts at unity in South Vietnam had not progressed to his satisfaction. Their recurring conclusion was that Asian audiences judged America by its deeds, its commitments and its staying power more than by its words. "
"Where FRUS points for the rest: the documents came from the records of the U.S. Information Agency, the Department of State's central decimal file and its lot files on National Security Council papers, and the Johnson, Kennedy, Nixon, Ford and Carter presidential libraries; the footnotes cite Department of State lots 66 D 95, 62 D 430, 63 D 351 and 62 D 1 and library files that FRUS does not print. "
"What this request cannot get from FRUS: any measurement of how Asian audiences received the messages, the messages themselves, and Asian voices other than through American summaries. The Agency's research reports, its Vietnam working group files and the Ford Library's Vietnam Information Group files hold more.")
col={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"Soft power in East Asia and the Pacific, 1949 to 1977",
 "authorLine":"Agent run, soft power in East Asia and the Pacific, 2026-10-31",
 "introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":entries}
json.dump(col,open('collection.fruscollection','w',encoding='utf8'),ensure_ascii=False,indent=2)
n_doc=sum(1 for e in entries if e["kind"]=="document"); n_ex=sum(1 for e in entries if e["kind"]=="excerpt")
print("documents",n_doc,"excerpts",n_ex,"entries",len(entries))
