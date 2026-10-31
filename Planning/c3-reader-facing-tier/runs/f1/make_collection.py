import json,csv,sqlite3
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
A="Agent run f1, 2026-10-31"
Q={}
for v,d,q in json.load(open('quotes.json')): Q.setdefault((v,d),[]).append(q)
intro=("What FRUS answers directly: across 22 documents from 1950 to 1977, policymakers judged America's standing in East Asia and the Pacific mostly as a matter of credibility - whether Asians believed U.S. commitments and saw American strength, reliability and friendship - and they built information programs aimed at elites, run increasingly through Asian governments. They doubted their own measures of effect, and their beliefs about the audience ranged from 'meager knowledge' of the United States (1950) to race-sensitivity, colonial suspicion and 'America watchers' (1969). "
 "Where FRUS points for the rest: the documents came mostly from USIA's own files in Record Group 306 (Director's Subject Files, Entry A1-42, and earlier director's files), presidential library national security files, and State's Executive Secretariat NSC policy-paper files (Lot 63 D 351/66 D 95, NAID 2839192); the editors also cite unprinted Central Decimal File class 511 (U.S. informational relations), OCB files (Lot 61 D 385) and SEA files (Lot 58 D 726, NAID 2544398). "
 "What this request cannot get from FRUS: the phrase 'soft power' and the word 'messaging' do not occur as such (both postdate the period); USIA's audience survey reports themselves are not printed; and no Asian audience speaks for itself here - reception is only seen through American reporting.")
E=[]
def doc(v,d,note):
    E.append({"kind":"document","volumeId":v,"documentId":d,"notes":[f"Agent finding, {A}: {note}"]})
    for q in Q.get((v,d),[]): E.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":q})
def head(t,p):
    E.append({"kind":"heading","text":t,"level":1}); E.append({"kind":"prose","text":p})
head("Information as the companion of aid and containment, 1950-1955","These five documents show the first frame: information work in Asia was justified as the explanatory arm of military and economic aid against communism, and its planners already worried about race, nationalism and colonial association.")
doc("frus1950v06","d50","Webb asks Truman for an intensified information and exchange program for Southeast and South Asia, premised on the region's meager knowledge of the United States.")
doc("frus1952-54v13p1","d116","Heath in Saigon reports on information objectives and admits films' effect can only be assumed; communist propaganda exploits nationalist and racial feeling.")
doc("frus1952-54v12p2","d403","PSB D-23: psychological strategy based on Thailand, aiming to prepare the minds and emotions of the people for collaboration.")
doc("frus1955-57v09","d190","USIA's mid-1955 status report: in the Far East it faced mixed emotions about atomic weapons used against Asian peoples and propaganda designed to stir up race hatred. Reached through a semantic-neighbour list.")
doc("frus1955-57v22","d447","USIA resists expanding its Malaya program partly for fear of appearing to support colonialism; FE overrides it.")
head("Vietnam, 1961-1963: propaganda campaigns and a damaged image","The Kennedy-era Vietnam documents show USIA mounting a deliberate campaign while its own officers warned that U.S. methods and the Diem government's conduct were hurting the American image in Asia.")
doc("frus1961-63v01","d49","USIA orders a major propaganda campaign on Viet Cong insurgency and depends on declassified material from Saigon.")
doc("frus1961-63v01","d265","USIA's Far East chief warns that defoliants could bring charges of germ warfare on Asians and a harvest of ill-will.")
doc("frus1961-63v02","d16","USIS Saigon: the GVN's image can be no better than the face it presents; credibility of U.S. news coverage at stake.")
doc("frus1917-72PubDipv06","d140","Mecklin's September 1963 memo: the U.S. image being hurt, and a belief about 'Orientals' and face shaping proposed tactics. A near-identical copy is printed in the Vietnam volume (1961-1963, IV, Document 81).")
head("Beliefs about the audience","These documents show whom USIA thought it was addressing in East Asia - elites, overseas Chinese, America-watchers - and what it believed those audiences thought of the United States.")
doc("frus1917-72PubDipv06","d126","USIA plans a campaign against Afro-Asian anti-American propaganda led by Indonesia, but expects the audience to discount words without deeds.")
doc("frus1917-72PubDipv07","d73","USIA Far East summary of 1966 country plans: elite target audiences; the image of American strength, reliability and friendship as the basic objective.")
doc("frus1917-72PubDipv07","d85","USIA Vietnam affairs officer after the 1966 Struggle movement: anti-Americanism under the surface, explained by Vietnamese history of colonization.")
doc("frus1917-72PubDipv08","d31","Summary of the 1969 East Asia PAO conference: Asians as America watchers; the U.S. image depends more on bilateral issues than on U.S. domestic events; PPBS evaluation not worth the effort.")
doc("frus1917-72PubDipv08","d149","1971 analysis of overseas Chinese attitudes in Southeast Asia as a USIS audience: apolitical, seeking neutrality.")
head("Measuring effect","These documents show how effect was measured - survey teams, Saigon opinion trend surveys, Japanese attitude surveys - and what the measures said.")
doc("frus1917-72PubDipv07","d32","1964 inspection of USIS Vietnam: survey teams valued as the best insight into rural attitudes; leaflets not pre-tested.")
doc("frus1917-72PubDipv08","d88","May 1970 Saigon opinion trend survey: rating of the U.S. as a dependable ally at its lowest in thirteen surveys.")
doc("frus1969-76v19p2","d67","Shakespeare to Kissinger, 1971: surveys of Japanese attitudes confirm strains in the relationship; asks for an NSC review.")
head("Handing the message to Asian governments, and selling staying power","From 1968 USIA sought to shift information work to Asian governments and, after 1975, to reassure East Asians that the United States would stay.")
doc("frus1964-68v27","d386","Marks to Johnson, 1968: Thailand lacks a national information program; USIA wants the Thai to assume programs it runs.")
doc("frus1917-72PubDipv08","d58","1969 Vietnamization of JUSPAO's information and psychological operations: USIA always saw its PSYOP role as short-term.")
doc("frus1917-72PubDipv08","d99","1970 Agency Program Memorandum: disengage from information support to Southeast Asian governments; do not take a favorable climate in Japan for granted. Reached through a semantic-neighbour list.")
doc("frus1969-76v38p2","d105","May 1975 post assessments after the fall of South Vietnam: security-relations programs lack credibility in Thailand; Korea and Philippines doubts.")
doc("frus1977-80v30","d79","1977 USIA East Asia memo: shoring up East Asian confidence in America's long-term staying power is real and necessary.")
E.append({"kind":"prose","text":"Threads not followed in this run: USIA's survey reports themselves (Office of Research; RG 306) are cited but not printed; the late-1940s and 1950s China record (the 1949 China volume and the 1955-1957 China microfiche supplement each hold more than forty matching documents) and the occupation-era programs in Japan and Korea were not read; cultural and educational exchange as distinct from information was not separated; Asian audiences' own records lie outside FRUS; and no 1981-1988 public diplomacy volume is among the 553 indexed."})
E.append({"kind":"generated","generatedBlockType":"archivalSources"})
coll={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"American soft power in East Asia and the Pacific: how policymakers assessed it",
 "authorLine":A,"introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":E}
pairs=[(e['volumeId'],e['documentId']) for e in E if e['kind']=='document']
assert len(pairs)==len(set(pairs)), "dup"
for e in E:
    if e['kind'] in('document','excerpt'): assert e.get('volumeId') and e.get('documentId')
for v,d in pairs: assert c.execute("SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone(), (v,d)
assert not any(v.endswith('Ed2') for v,d in pairs)
assert set(pairs)==set(map(tuple,csv.reader(open('argset.csv'))))
assert set(Q)<=set(pairs)
json.dump(coll,open('collection.fruscollection','w'),ensure_ascii=False,indent=1)
print("docs",len(pairs),"excerpts",sum(e['kind']=='excerpt' for e in E),"entries",len(E))
