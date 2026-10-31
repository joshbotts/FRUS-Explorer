import json,sqlite3
A="Agent finding, run f2, 2026-10-31: "
Q={l.split("\t")[0]:l.rstrip("\n").split("\t") for l in open("quotes.tsv")}
def ex(q): _,v,d,t=Q[q]; return {"kind":"excerpt","volumeId":v,"documentId":d,"text":t}
def doc(v,d,note): return {"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]}
E=[]
E+= [{"kind":"heading","text":"Speak through Asians, and keep the American voice out of sight (1950s)","level":1},
 {"kind":"prose","text":"These three documents show the first assumption of the strategy papers: that an Asian audience would resist an openly American message, and that themes recalling race, war or Western dominance were dangerous. They follow the thread from a psychological strategy for Thailand to the information agency's own account of its Far East work."},
 doc("frus1952-54v12p2","d403","The Psychological Strategy Board's plan for Thailand makes indigenous leadership the channel for American influence and aims to prepare popular attitudes for collaboration."),ex("Q1"),ex("Q2"),
 doc("frus1952-54v12p2","d352","The Department declines to amplify the Philippine 'Asia for Asians' theme because it would recall Japan's wartime slogan and sound anti-Western; it prefers 'free Asian solidarity' within the free world."),ex("Q25"),ex("Q3"),
 doc("frus1955-57v09","d190","The information agency's status report for mid-1955; its Far East section names the audience's sensitivities (atomic weapons, race) and credits a symphony tour with Japan's warmest response. Found by its similarity to the 1969 regional conference report, by no word search, and read before it was cited."),ex("Q4"),ex("Q5"),
 {"kind":"heading","text":"Vietnam: a surrogate voice, and doubts about the audience (1963–1969)","level":1},
 {"kind":"prose","text":"These documents follow the agency's attempt to speak behind the South Vietnamese government: its caution about anti-Chinese themes, its field officers' low opinion of the audience, and its plan to hand psychological work to Saigon."},
 doc("frus1917-72PubDipv06","d128","Murrow weighs a campaign tying Hanoi to Peking and warns that it may magnify the threat and offend South Vietnam's Chinese residents; he prefers editorial emphasis and Vietnamese-placed articles."),ex("Q7"),ex("Q8"),
 doc("frus1917-72PubDipv07","d32","A 1964 field review: the agency acts as a surrogate information service for Saigon, holds that Vietnamese must persuade Vietnamese, and judges the civil population harshly."),ex("Q10"),ex("Q11"),
 doc("frus1917-72PubDipv08","d58","The agency describes 'Vietnamization' of its information and psychological operations, which it always regarded as belonging to the Vietnamese government."),ex("Q17"),
 {"kind":"heading","text":"Effectiveness was measured by reaction, and policy outweighed persuasion (1963–1970)","level":1},
 {"kind":"prose","text":"These documents show how officials judged effect: by a visitor's reception, by press comment across the region, and by opinion surveys. They follow the thread from a successful tour to the conclusion that unpopular policy could not be offset by information work."},
 doc("frus1917-72PubDipv06","d127","Ambassador Reischauer rates John Glenn's 1963 visit as the most successful American visit to Japan from a public-image standpoint, crediting his openness and modesty."),ex("Q6"),
 doc("frus1961-63v03","d308","Murrow's survey of world press reaction to the Diem government's repression; the Far East press blames the United States for keeping Diem in power."),ex("Q9"),
 doc("frus1964-68v29p2","d46","Reischauer's assessment of Japanese reaction to the bombing of North Vietnam: falling poll figures, an emotional response he thinks information work cannot change, and Japanese memory of their own war in China."),ex("Q14"),ex("Q12"),ex("Q13"),
 doc("frus1917-72PubDipv08","d88","Saigon opinion survey results for May 1970, with the lowest rating of the United States as a dependable ally in the series."),ex("Q18"),
 {"kind":"heading","text":"Image follows the alliance: modesty, low visibility and segmented audiences (1969–1971)","level":1},
 {"kind":"prose","text":"These documents show the agency's regional officers concluding that America's image followed bilateral relations, preferring a low American profile, and reading audiences community by community."},
 doc("frus1917-72PubDipv08","d31","Summary of the 1969 Manila conference of the agency's East Asia public affairs officers: image follows bilateral relations; 'modesty, mutuality and multi-lateralism'; low American visibility."),ex("Q15"),ex("Q16"),
 doc("frus1969-76v19p2","d67","The agency's director asks for a new review of Japan policy, citing surveys that confirm strains in the alliance and the psychological effect of American force reductions."),ex("Q19"),
 doc("frus1917-72PubDipv08","d149","An agency report on overseas Chinese attitudes in Southeast Asia after the opening to China, treating them as a distinct audience."),ex("Q20"),ex("Q21"),
 {"kind":"heading","text":"After 1975: credibility of commitment, and a turn to elites (1975–1977)","level":1},
 {"kind":"prose","text":"These documents follow the posts' reassessment after the fall of Saigon, where credibility of commitment became the problem, and a shift toward exchanges among opinion-makers."},
 doc("frus1969-76v38p2","d105","Post-by-post abstracts of the agency's East Asia reassessment after the fall of South Vietnam: credibility of American commitments is the common concern, and themes shift to the vitality of American society."),ex("Q22"),ex("Q23"),
 doc("frus1977-80v30","d2","The agency brokers exchanges among Japanese, European and American economic editors over trade frictions."),ex("Q24"),
 {"kind":"prose","text":"Threads not followed: the agency's own survey reports and Asian-language press, which FRUS prints only in summary; the Laos information-media struggle of 1962–1963 in the Public Diplomacy volume for 1961–1963; the Southeast Asia and Pacific volume for 1977–1980; and anything after 1980."},
 {"kind":"generated","generatedBlockType":"archivalSources"}]
ov=open("overview.md").read()
p1=ov.split("**1. What FRUS answers directly.**")[1].split("**2.")[0].strip()
p2=ov.split("**2. Where FRUS points for the rest.**")[1].split("**3.")[0].strip()
p3=ov.split("**3. What this request cannot get from FRUS.**")[1].split("**Scope.**")[0].strip()
coll={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"American soft power in East Asia — run f2","authorLine":"Agent run f2, 2026-10-31",
 "introductionText":"What FRUS answers directly: "+p1+"\n\nWhere FRUS points for the rest:\n"+p2+"\n\nWhat this request cannot get from FRUS: "+p3,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":E}
json.dump(coll,open("collection.fruscollection","w"),ensure_ascii=False,indent=1)
# checks
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
docs=[(e["volumeId"],e["documentId"]) for e in E if e["kind"]=="document"]
assert len(docs)==len(set(docs)), "dup"
for e in E:
    if e["kind"] in("document","excerpt"):
        assert e.get("volumeId") and e.get("documentId")
        r=c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(e["volumeId"],e["documentId"])).fetchone()
        assert r, e
        if e["kind"]=="excerpt": assert e["text"] in r[0], e; assert (e["volumeId"],e["documentId"]) in docs
assert not any(v.endswith("Ed2") for v,_ in docs)
import re
cited=set(re.findall(r"historicaldocuments/([^/\s]+)/(d\d+)",ov))
print("docs",len(docs),"excerpts",sum(e["kind"]=="excerpt" for e in E),"overview cited",len(cited),"cited-not-in-collection",cited-set(docs),"collection-not-cited",set(docs)-cited)
