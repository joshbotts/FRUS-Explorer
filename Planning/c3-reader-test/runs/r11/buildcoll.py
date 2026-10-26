# Build collection.fruscollection from findings plan + quotes.json; verify every pair exists in document_cache, no duplicates, no Ed2.
import json
from db import q
Q={x[0]:x for x in json.load(open("quotes.json"))}
A="Agent finding, run r11, 2026-10-25: "
F=[
("Before 1913: control of the government and the people's acquiescence",
 "Nineteenth-century instructions on revolutionary changes in Colombia, Venezuela and Ecuador. They show the test of the period: possession of the machinery of government, the people's acquiescence and respect for treaty obligations, with formal recognition reserved to Washington.",
 [("frus1868p2","d632","Seward (1867) states the practice: no recognition of a revolutionary change without evidence of the people's acquiescence; recognizes Acosta's de facto executive once general consent appears.",["Q1"]),
  ("frus1868p2","d598","Seward (1868) recognizes Venezuela's provisional government once the civil war has ended and resistance has collapsed.",[]),
  ("frus1895p1","d244","Adee (Sept. 1895): the minister may do current business with a de facto authority that controls the machinery of government with general acquiescence; formal recognition waits for instructions.",[]),
  ("frus1895p1","d246","Olney (Nov. 1895) gives the full test for Alfaro's Ecuador: establishment with general consent, possession of the executive forces, regard for international law and treaties.",["Q2","Q3"]),
  ("frus1899","d805","Hay (1899) ignores the change of government in Venezuela until recognition is formally requested.",[])]),
("1913–1934: a test of constitutional origin, and the Central American treaty rule",
 "Wilson's statement, its application to Tinoco, and the 1923 treaty rule as adopted by Hughes and applied by Stimson. The thread is the manner of coming to power as a bar to recognition.",
 [("frus1913","d7","Wilson's statement of 11 March 1913, circulated to missions in Latin America: cooperation requires government based on law, not irregular force.",["Q4"]),
  ("frus1917","d379","Lansing (Feb. 1917): no government in Costa Rica except one legally elected and constitutionally established will be recognized; Tinoco is told so.",["Q5"]),
  ("frus1923v02","d345","Hughes (June 1923) publishes the United States' adherence to Article II of the 1923 Central American treaty, including its bar on coup leaders and relatives.",["Q6"]),
  ("frus1932v05","d618","Stimson (Jan. 1932): Martínez cannot be recognized under the treaty; the Department will accept any first designate eligible under it.",["Q7"])]),
("What Washington asked for: obligations, property and a promise of elections",
 "Two statements of the price of recognition outside the treaty zone: guarantees for property in Mexico, and the 1930 South American test of control, no resistance, obligations and elections.",
 [("frus1921v02","d344","Hughes (June 1921): recognition of Obregón will come with a treaty safeguarding property rights acquired before the 1917 constitution.",["Q8"]),
  ("frus1930v01","d375","Stimson's press release (Sept. 1930) recognizing Argentina, Peru and Bolivia: de facto control, no active resistance, intention to meet obligations and hold elections; the Central American treaty rule is called an exception.",["Q9"])]),
("Giving up the treaty rule, 1934–1936",
 "The Central American states recognize Martínez first, and the Department then drops Article II as its guide.",
 [("frus1934v05","d220","Welles (Jan. 1934) backs recognition of Martínez's government by Guatemala, Honduras and Nicaragua, then by the United States.",["Q11"]),
  ("frus1936v05","d112","Confidential instruction (Apr. 1936): the United States should no longer be guided by Article II in recognizing Central American governments.",["Q10"])]),
("Wartime: consultation, with hemisphere defense as the test",
 "The Montevideo committee's resolution and its use for Bolivia, Guatemala and El Salvador, then Haiti in 1946. The thread is recognition as a collective decision, with commitments to continental defense as the condition.",
 [("frus1943v05","d33","Guani transmits the Montevideo committee's recommendation (Dec. 1943): consult before recognizing any government instituted by force, to determine whether it complies with inter-American defense undertakings.",["Q12"]),
  ("frus1944v07","d428","Hull (May 1944): Bolivia's provisional government expels Axis aliens with United States help; Hull says the action is not connected with recognition, which is for the consulting republics.",["Q13"]),
  ("frus1944v07","d438","Hull (June 1944) proposes that each government announce recognition of Bolivia as the result of full consultation under the Montevideo recommendation.",[]),
  ("frus1944v07","d1088","Stettinius (Oct. 1944): no recognition of the new regimes in Guatemala and El Salvador until information has been exchanged under Resolution 22.",["Q23"]),
  ("frus1946v11","d773","Byrnes (Mar. 1946) on Haiti's junta: control, order, popular support, a promise to fulfill international commitments, elections; action only on a consensus of the republics.",["Q14"])]),
("After Bogotá: relations without approval, and terms negotiated case by case",
 "From the 1948 policy paper and the Bogotá resolution to Peru 1962, the Dominican Republic 1963, Argentina 1966, Peru 1968 and Chile 1973. The thread is recognition separated from approval, while suspension, consultation and negotiated conditions continue.",
 [("frus1948v09","d7","Policy Planning Staff paper (Mar. 1948): reviews the de facto tradition, the Ecuadoran and Guatemalan proposals and the Estrada Doctrine; weighs effective control and ability to meet obligations as the criteria.",["Q15"]),
  ("frus1948v09","d119","Lovett (Dec. 1948) after the Venezuelan coup: Bogotá Resolution 35 approved on the view that non-recognition does not suit the problem of dictatorship; a recognition note may record the junta's promise of elections.",["Q16"]),
  ("frus1949v02","d454","Acheson (Feb. 1949) on Paraguay: doubts that suspending relations would encourage democracy; cites Bogotá Resolution 35.",["Q22"]),
  ("frus1961-63v12","d421","Ball to Kennedy (July 1962): what the Peruvian junta must do before relations resume; most governments have suspended relations.",["Q17"]),
  ("frus1961-63v12","d359","Instruction (Oct. 1963): conditions to be agreed by the Dominican regime before recognition or aid, beginning with free party activity and OAS-supervised elections within a year.",["Q18"]),
  ("frus1964-68v31","d132","Instruction (June 1966) after the Argentine coup: relations suspended, consultation promised; the editors' footnote summarizes the 1965 Rio Resolution XXVI criteria.",["Q24","Q19"]),
  ("frus1964-68v31","d512","Oliver (Oct. 1968) on Peru: practice in responding to coups no longer fits the traditional doctrine; floats a variant of the Estrada Doctrine.",["Q21"]),
  ("frus1969-76v21","d361","Washington Special Actions Group (Sept. 1973) agrees to announce recognition of Chile's junta on 24 September; the junta is called an established fact.",["Q20"])]),
]
intro=("What FRUS answers directly: the decision rule and the price of recognition changed four times. Before 1913 Washington asked for control of the government, the people's acquiescence and respect for treaties. From 1913 to 1934 it added constitutional origin, and in Central America the 1923 treaty rule barred coup governments until freely elected representatives reorganized the country. In Mexico and South America the price was guarantees of obligations and property, and a promise of elections. That rule was dropped in 1936; during the war recognition became a collective decision tested by hemisphere defense; after Bogotá in 1948 recognition carried no approval, but in the 1960s Washington still bargained for elections before resuming relations. The evidence is about 940 documents in 87 of 553 volumes. "
 "Where FRUS points for the rest: the printed documents came mainly from the Department of State's Central Decimal File (Record Group 59), especially the per-country Government subfiles (El Salvador 816.01, Bolivia 824.01, Argentina 835.01, Ecuador 822.01, Guatemala 814.01). The bundle gives no entry number, identifier or access status for that file. Before 1906 they are ministers' despatches and instructions (Despatches from U.S. Ministers, series 603720; Diplomatic Instructions, series 593313), and a few post-1950 documents are from lot files such as RG 59 A1 3159 (NAID 1750062). The editors cite unprinted material in about one document in fourteen: decimal files, and lots such as RG 59 A1 3157 (NAID 2363840), A1 1135 (NAID 2108779), A1 3147 (NAID 2068466) and A1 5376 (NAID 631695). "
 "What this request cannot get from FRUS: Mexico's 1930 Estrada declaration (not printed; the doctrine appears only second-hand, from 1931); the Department's 1947 study of recognition policy (not printed, no file given); and recognition decisions after 1980 (one scope document in the 1980s).")
entries=[]; seen=set()
for h,prose,docs in F:
    entries.append({"kind":"heading","text":h,"level":1})
    entries.append({"kind":"prose","text":prose})
    for v,d,note,qs in docs:
        assert (v,d) not in seen and not v.endswith("Ed2"); seen.add((v,d))
        r=q("SELECT COUNT(*) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d),tag="buildcoll-verify")[0][0]; assert r==1,(v,d)
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]})
        for qi in qs:
            x=Q[qi]; assert x[1]==v and x[2]==d
            entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":x[3]})
entries.append({"kind":"heading","text":"Threads not followed","level":1})
entries.append({"kind":"prose","text":"Not followed in this pass: the Huerta and Carranza recognition questions of 1913–1917, counted in scope but not read closely; the Obregón negotiations of 1922–1923 that produced recognition; Cuba, Haiti, Panama and the Dominican Republic under treaty or occupation; the 1950s cases (Bolivia 1952, Guatemala 1954, Venezuela 1958, Cuba 1959), present in the scope but not read; Brazil 1964 and Panama 1968; the late-1970s idea of recognizing states rather than governments (eight documents found, none read); and the Latin American governments' own reasoning, including Mexico's Estrada declaration, which FRUS does not print."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
coll={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"Recognizing governments that took power by force — Latin America",
 "authorLine":"Agent run r11, 2026-10-25",
 "introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":entries}
json.dump(coll,open("collection.fruscollection","w"),ensure_ascii=False,indent=1)
print("documents",len(seen),"excerpts",sum(1 for e in entries if e["kind"]=="excerpt"))
cited=set(tuple(l.split()) for l in open("cited.txt")); print("cited==collection",cited==seen)
