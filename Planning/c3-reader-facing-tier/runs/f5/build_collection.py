# build_collection.py: writes collection.fruscollection, verifying every pair exists and every excerpt is a substring of its document
import json,re,sys
sys.path.insert(0,'/Users/jbotts/frus-analysis/c3f/runs/f5')
from h import *
from quotes import Q,norm
RUN="Agent run of 2026-10-31 (soft power in East Asia and the Pacific)"
def note(s): return [f"{RUN}: {s}"]
Qd={}
for v,d,q in Q: Qd.setdefault((v,d),[]).append(q)
def ex(v,d,i): return {"kind":"excerpt","volumeId":v,"documentId":d,"text":Qd[(v,d)][i]}
def doc(v,d,n,exs=()):
    out=[{"kind":"document","volumeId":v,"documentId":d,"notes":note(n)}]
    for i in exs: out.append(ex(v,d,i))
    return out
E=[]
H=lambda t:E.append({"kind":"heading","text":t,"level":1})
P=lambda t:E.append({"kind":"prose","text":t})
# Finding 1
H("What they did: counter-propaganda, leaders first, and exchange (1948-1956)")
P("These seven documents show the repertoire as the policymakers wrote it down: contrast the United States with the Soviet Union, reach educated and official leader groups before the masses, send Chinese-language material to the Chinese minorities of Southeast Asia, pair information with aid, and use broadcasting, libraries, film and exchanges. Each is chosen because it states an intended message or channel in the author's own words, not because it records a result.")
E+=doc("frus1948v07","d567","The Department's reply to Ambassador Stuart on the China information program: use the newsletter for the educated middle group, show what happens where communists take power, and keep 'moral leadership' by discussing America's own faults.",[0,1])
E+=doc("frus1949v08","d499","Stuart asks for a large expansion of USIS in every Southeast Asian country, with Chinese-language print for the Chinese minorities.",[0])
E+=doc("frus1949v07p2","d386","Jessup's November 1949 memorandum asks for a much larger information program in communist and non-communist Asia, built on sympathy for nationalism.",[0])
E+=doc("frus1950v06","d50","Webb argues that information must accompany military and economic aid in Southeast Asia, and describes the audience as low in literacy and ignorant of American policy.",[0])
E+=doc("frus1952-54v12p2","d359","NSC 5413 for the Philippines lists USIA's tools (libraries, press, anti-communist films, radio) and states how far funding cuts reduced them in fiscal 1954.",[0])
E+=doc("frus1955-57v09","d190","The NSC's report on the foreign information program for 1955: USIA aims in the Far East after Geneva and Bandung, including orienting Asian neutralists toward the United States.",[0])
E+=doc("frus1955-57v22","d484","OCB staff study on Thailand: the USIA program is described as anti-communist indoctrination working down from 28 top leaders to the rural border areas.",[0])
# Finding 2
H("What they believed about the audience")
P("Officials wrote of Asian audiences as sceptical of American words, quick to hear colonialism in a Western theme, hard to reach through weak media and low literacy, sensitive to 'face', and divided between leaders and masses. Those are the officials' beliefs, in the vocabulary of their day, collected here as beliefs and not as findings about Asian peoples.")
E+=doc("frus1949v07p2","d127","Sebald in Tokyo reports that many Japanese found the Occupation ignorant of 'the Oriental'. It is an American official's belief about how the audience saw American methods.",[0])
E+=doc("frus1952-54v12p2","d251","Report on Indonesia: USIS works where people judge the United States by actions, not words, and distrust non-Asian propaganda. The same report gives the Public Affairs Officer's guess at the distribution of opinion.",[0])
E+=doc("frus1952-54v12p2","d352","The Department rejects use of an 'Asia for Asians' theme by USIA because it recalls the Japanese wartime slogan and could be read as anti-Western.",[0])
E+=doc("frus1955-57v22","d447","Robertson records why USIA resisted expanding in Malaya: budget, a wish for the British to carry the work, and a fear of seeming to back colonialism.",[0])
E+=doc("frus1958-60v15","d548","OCB report on Thailand: information work faces weak media and low means of communication, but a government already firmly anti-communist.",[0])
E+=doc("frus1961-63v04","d81","Mecklin's memorandum written en route from Saigon: its argument is about force and a coup, but it states a belief about Vietnamese leaders and 'Orientals' and capitulation.",[0])
E+=doc("frus1917-72PubDipv08","d149","USIA's East Asia office, polling its posts in 1971, finds the overseas Chinese apolitical and neutral rather than ideological.",[0])
# Finding 3
H("How effective they thought it was")
P("The assessments in this group are almost all made by the programme's own officers. The earliest say effect cannot be measured; from 1962 the language turns to failure: the weakest part of the war, a program that has not progressed, an operation with nothing worthwhile left.")
E+=doc("frus1952-54v13p1","d116","Ambassador Heath answers a request for an assessment of the information program in Indochina: films, libraries and English classes are counted as effective, with the admission that the degree cannot be measured.",[0])
E.append(ex("frus1952-54v12p2","d251",1))
E+=doc("frus1961-63v02","d197","Mecklin asks the PsyOps committee for a hard reading on how well Vietnamese government propaganda works, after hearing that its content is poor and too negative.",[0,1])
E+=doc("frus1964-68v01","d122","Rowan reports to the President that information and psychological warfare is the weakest part of the war effort, and that the program has failed in provinces for lack of small sums.",[0,1])
E+=doc("frus1917-72PubDipv07","d32","Tull's field review of USIS Vietnam: the government's information service is not doing its job and motivation is the number one problem.",[1])
E+=doc("frus1964-68v26","d106","Rowan on the loss of USIS capability in Indonesia: attacks have left little worth keeping, and he argues for penalties rather than voluntary closure.",[0])
E+=doc("frus1964-68v02","d160","Rowan to President Johnson on the psychological program in Vietnam: some headway in Hop Tac areas but national unity and will-to-fight efforts have not progressed to his satisfaction.",[0])
# Finding 4
H("The host government as messenger")
P("In Vietnam and Thailand the Americans wanted the local government to speak to its own people. These documents show why that put the ceiling on the effort: the host service was weak or unmotivated, and Washington's response was to place advisers and money inside it.")
E+=doc("frus1961-63v01","d49","USIA's Far East office orders a major propaganda campaign on Viet Cong insurgency in May 1961 and asks Saigon to get material declassified.",[0])
E+=doc("frus1961-63v02","d16","Neilson's briefing for the Ambassador: should USIS put American information advisers at the Presidency and in the provinces; the GVN's image abroad can be no better than the face it presents at home.",[0])
E.append(ex("frus1917-72PubDipv07","d32",0))
E+=doc("frus1964-68v01","d177","Rowan's list of fourteen steps: more USIA staff for Vietnam, Defense-trained province advisers, a petty-cash fund, and a large expansion of VOA broadcasting to the North.",[0])
E+=doc("frus1917-72PubDipv07","d85","Marlowe, after the 1966 Buddhist crisis: the Americans had not reckoned with the anti-Americanism under the surface in Vietnam.",[0])
E+=doc("frus1964-68v27","d386","Marks briefs President Johnson for a meeting with the Thai Prime Minister: Thailand lacks a national information program, and USIA runs programs it wants the Thai to take over.",[0])
# Finding 5
H("After Vietnam: credibility follows policy")
P("From 1969 USIA officers say the audience judges the United States by its policy and commitments, not by its programs. After the fall of Saigon they ask Washington to settle the policy first. The 1977 documents show the message becoming reassurance.")
E+=doc("frus1917-72PubDipv08","d31","The 1969 Manila conference of USIA's East Asia and Pacific public affairs officers: audiences watch America, and image depends on bilateral relations; officers are unsure what US commitments are.",[0,1,2])
E+=doc("frus1917-72PubDipv08","d99","USIA's first Agency Program Memorandum (1970): under the new partnership, the United States will have to lower its voice.",[0])
E+=doc("frus1969-76v19p2","d67","Shakespeare to Kissinger on Japan in 1971: opinion surveys confirm strains, and he proposes a new policy review that asks about the psychological effect of force reductions.",[0])
E+=doc("frus1969-76v38p2","d105","USIA's East Asia office abstracts its posts' reassessment after the fall of Vietnam: programs on security lack credibility until policy is stated; Burmese see the gap between words and deeds.",[0,1])
E+=doc("frus1977-80v22","d104","Sullivan from Hong Kong in 1977: the 1975 public position that nothing had changed did not reassure ASEAN or Japan.",[0])
E+=doc("frus1977-80v30","d79","USIA's East Asia assistant director to the Deputy Director, July 1977: the Administration's statements are meant to shore up East Asians' confidence in American staying power.",[0])
P("Threads not followed. (1) USIA's own opinion-research reports and post-by-post reviews at the National Archives were not reached; FRUS prints only what the editors chose. (2) Japan, Korea and Australasia are thin in this set; the cultural and educational exchange programs (Fulbright, leader grants) were scanned but no printed document was selected, because the ones found describe exchanges without assessing them. (3) The reception of the messages in local press and by local audiences is not in FRUS. (4) What the Voice of America actually broadcast, and in which languages, was not read beyond the Vietnamese expansion of 1964. (5) The 1945-1947 volumes were scanned and nothing was selected. (6) The Chinese mainland as an audience, 1949-1950 and after 1971, was not followed. (7) Documents on policy toward South Asia and the Middle East were left out by the region rule.")
E.append({"kind":"generated","generatedBlockType":"archivalSources"})
intro=("What FRUS answers directly: policymakers described their messages to East Asia and the Pacific as information programs and psychological operations, wrote down the tools and the audience beliefs behind them, and, from the early 1960s, judged the effort weak; thirty-one documents carry that argument. "
"Where FRUS points for the rest: the printed documents came mostly from State Department central and Executive Secretariat files (record group 59, lots 61 D 167, 62 D 430, 63 D 351 and 61 D 385) and from the United States Information Agency's own files (record group 306, including the Director's subject files, accession 72 A 5121) and the Johnson Library's National Security File; the footnotes point at Nixon-era NSC Files, Executive Secretariat lot 66 D 95, and Johnson and Kennedy Library files that FRUS cites without printing. "
"What this request cannot get from FRUS: the phrase soft power does not occur in any of the 553 volumes; measured audience reception is absent; USIA's research and field-post files at the National Archives (record group 306) hold the rest.")
col={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"Soft power in East Asia and the Pacific: messaging and its limits, 1948-1980",
 "authorLine":"Agent run, 2026-10-31",
 "introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":E}
# verification
c=conn()
seen=set(); bad=0
SQL="SELECT is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?"
for e in E:
    if e["kind"] in ("document","excerpt"):
        assert "volumeId" in e and "documentId" in e
        r=c.execute(SQL,[e["volumeId"],e["documentId"]]).fetchone(); assert r and r==(0,0), e
    if e["kind"]=="document":
        k=(e["volumeId"],e["documentId"]); assert k not in seen, k; seen.add(k)
        assert not e["volumeId"].endswith("Ed2")
    if e["kind"]=="excerpt":
        t=norm(open(f"docs/{e['volumeId']}__{e['documentId']}.txt").read())
        if norm(e["text"]) not in t: bad+=1; print("EXCERPT NOT FOUND",e["volumeId"],e["documentId"])
used={(e["volumeId"],e["documentId"],e["text"]) for e in E if e["kind"]=="excerpt"}
unused=[q for q in Q if q not in used]
print("documents",len(seen),"excerpts",len(used),"quotes defined",len(Q),"unused quotes",len(unused),"bad",bad)
for u in unused: print("UNUSED",u[0],u[1],u[2][:60])
SET={tuple(l.strip().split('/')) for l in open('collection_set.txt') if l.strip()}
print("set equals collection documents:",SET==seen)
json.dump(col,open('collection.fruscollection','w'),indent=2,ensure_ascii=False)
