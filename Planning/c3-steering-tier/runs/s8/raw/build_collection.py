# Build collection.fruscollection; excerpt texts are taken verbatim from raw/quotes.json (verified in raw/verify.out)
import json
Q={x[0]:x for x in json.load(open("raw/quotes.json"))}
A="Agent finding, run s8, 2026-10-30: "
def doc(v,d,note): return {"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]}
def ex(q): x=Q[q]; return {"kind":"excerpt","volumeId":x[1],"documentId":x[2],"text":x[3]}
E=[]
E+= [{"kind":"heading","text":"China: corruption as the argument for holding back military aid, 1947–48","level":1},
 {"kind":"prose","text":"The China volumes of 1947 and 1948 hold more corruption documents than any others. These six show the Department turning the Nationalist government's venality into a reason to vet, delay or withhold aid, and Chiang's reply that this was why he needed American help. Date order."},
 doc("frus1947v07","d617","Vincent proposes that every aid project be examined for waste or corrupt management by officials seeking personal gain."), ex("Q2"),
 doc("frus1947v07","d628","Marshall argues against premature military aid: it would tell reactionaries that support came regardless of party corruption, and prevent reform."), ex("Q1"),
 doc("frus1947v07","d582","Wedemeyer reports from Nanking that Shanghai, Formosa and Canton confirm corrupt and inept practices."), ex("Q3"),
 doc("frus1947v07","d583","Sprouse's reform list for Wedemeyer: police pay to prevent graft, a strengthened Control Yuan to eliminate corruption."),
 doc("frus1948v07","d322","Stuart reports Chiang's retort that the Americans call his government corrupt yet do little to help it reform."), ex("Q4"),
 doc("frus1948v07","d407","The Department's October 1948 review cites reports that Chiang appointed comrades regardless of their proven corruption.")]
E+= [{"kind":"heading","text":"South Vietnam: from private démarche to public-relations requirement, 1960–68","level":1},
 {"kind":"prose","text":"Corruption is raised quietly with Diem's government in 1960, denied by Diem, and by 1966–68 has become a matter of U.S. domestic politics: Washington wants a visible anti-corruption drive in Saigon to answer critics at home. Date order."},
 doc("frus1958-60v01","d135","The Department reports that Parsons and Wood raised corruption with Thuan in April 1960."),
 doc("frus1958-60v01","d267","Durbrow reports Diem rejecting press stories of corruption and family rule as propaganda."), ex("Q5"),
 doc("frus1964-68v04","d215","Ky tells Lodge that two senior generals are corrupt; one opposed U.S. troops in IV Corps because they would interfere with his practices."),
 doc("frus1964-68v05","d395","Katzenbach reports the senior advisers' unanimous view that a credible anti-corruption effort would help the Administration's position."), ex("Q6"),
 doc("frus1964-68v06","d31","Notes of meeting: Johnson, facing a Senate charge of corruption, says the U.S. has corruption too."), ex("Q7"),
 doc("frus1964-68v06","d134","The embassy urges that Saigon's disciplining of 74 officials be used to meet criticism in the United States."), ex("Q21")]
E+= [{"kind":"heading","text":"South Korea: aid conditioned on reform, and the junta's charges distrusted, 1961–63","level":1},
 {"kind":"prose","text":"After the 1960 revolution Washington ties Korean aid to performance, anti-corruption measures included; when the military junta later uses 'corrupt' as a label to purge politicians, the Department questions it. Date order."},
 doc("frus1961-63v22","d202","An aid official warns that graft, corruption and fraud endanger the U.S. position and the aid program in Korea."), ex("Q10"),
 doc("frus1961-63v22","d221","NSC staff recommend making aid above a maintenance level conditional on performance, with actions against corruption."), ex("Q8"),
 doc("frus1961-63v22","d297","The Department questions the junta's offer to compromise if 'corrupt' politicians withdraw."), ex("Q9")]
E+= [{"kind":"heading","text":"American firms' payments abroad: managing allies and proposing rules, 1974–76","level":1},
 {"kind":"prose","text":"Here the corruption is American companies'. The documents follow the Saudi agents' fees, the Senate revelations about Lockheed in Germany, the Netherlands and Japan, and three different diplomatic responses: discretion, disclosure with a proposal for international rules, and disclaiming executive control. Date order."},
 doc("frus1969-76ve09p2","d122","The Jidda embassy's survey of Saudi corruption and its risk to the regime, to American firms and perhaps to the U.S. government."), ex("Q11"),
 doc("frus1969-76ve09p2","d152","At the Secretary's staff meeting, Mr. Maw describes the agents' fees stalling the Saudi air-force program and his position on disclosure."), ex("Q12"),
 doc("frus1969-76ve09p2","d155","Kissinger's briefing for Saudi Arabia lists the Church subcommittee's Khashoggi revelations among strains on the relationship. Found as a semantic neighbour of the Jidda airgram and in the Lockheed-payments search."), ex("Q19"),
 doc("frus1969-76ve09p2","d161","Akins meets Sultan on the Lockheed bribery situation; the editors' note says the embassy was to say the matter lay outside executive control."), ex("Q22"),
 doc("frus1969-76ve15p2","d292","Hartman relays the subcommittee staff's findings: Lockheed bribes to Strauss and the CSU paved the way for the Starfighter sale."), ex("Q14"),
 doc("frus1969-76ve15p2","d293","The editors' note quotes Kissinger telling Ford to keep the German and Dutch payments quiet."), ex("Q13"),
 doc("frus1969-76ve12","d218","Miki asks Ford for help in disclosing the names of Japanese officials in the Lockheed affair."),
 doc("frus1969-76ve12","d219","Ford offers to share the information and proposes an international agreement against corrupt practices."), ex("Q15"),
 doc("frus1969-76ve09p1","d50","Libya's note after Qadhafi alleged a Lockheed bribe; the Department's reply on the company's questionable payments."),
 doc("frus1969-76ve12","d227","The Tokyo embassy reports Tanaka's arrest over Lockheed funds as the ruling party's biggest scandal."), ex("Q16")]
E+= [{"kind":"heading","text":"Nicaragua: a charge heard and set aside, 1978","level":1},
 {"kind":"prose","text":"Corruption is charged against Somoza by Venezuela's president and by the opposition, and listed by the State Department; the Central America office director argues it is not the cause of Somoza's crisis. Date order."},
 doc("frus1977-80v15","d68","State's action memorandum lists government corruption among Nicaragua's remaining problems; the editors' note quotes Pérez."), ex("Q20"),
 doc("frus1977-80v15","d80","The embassy transmits the opposition program, which begins its reforms with eradicating Somocista corruption."), ex("Q18"),
 doc("frus1977-80v15","d83","Matthews argues that regime fatigue, not corruption, is the cause of Somoza's difficulties."), ex("Q17")]
E+= [{"kind":"prose","text":"Threads not followed in this run: corruption among U.S. aid and military personnel; the black market; the 1950s Indochina and 1951–54 Iran volumes; the 1973–76 Latin American documents; the Philippines and Indonesia, 1964–68; the nineteenth-century claims cases and the 1894 Hawaii appendix; the making of the Foreign Corrupt Practices Act; and the Church subcommittee's and SEC's own investigative files, which FRUS does not print."},
 {"kind":"generated","generatedBlockType":"archivalSources"}]
intro=("What FRUS answers directly: corruption shaped U.S. policy in three ways — as a reason to withhold or condition aid (China 1947, Korea 1961), as a domestic political liability Washington tried to manage through its allies (South Vietnam 1966–68), and, in 1975–76, as American firms' own payments abroad, which diplomats had to contain or disclose (Lockheed in Germany, the Netherlands, Japan and Saudi Arabia). The argument rests on 28 documents from 12 volumes, 1947–1978, drawn from about 2,200 documents in the 553-volume series that mention corruption. "
 "Where FRUS points for the rest: the documents came from the State Department's Central Decimal File, Subject-Numeric files and Central Foreign Policy File (RG 59), the Jidda Embassy files (RG 84, Lot 79F80), Deputy Secretary Christopher's records (Lot 81D113, NAID 1487627), and the Kennedy, Johnson, Ford and Carter libraries; the editors cite, unprinted, the Far Eastern Affairs files of Lot 62D26 (NAID 1965953) and the NSC Policy Papers lots 63D351/66D95 (NAID 2839192). "
 "What this request cannot get from FRUS: the Church subcommittee's and SEC's own investigative files (24 FRUS documents in 15 volumes name the subcommittee; no bundled shelf); the making of the Foreign Corrupt Practices Act (4 documents, 1978–80, all after passage); and archival pointers before December 1910, where the citation data begins.")
C={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,"name":"Corruption and U.S. diplomacy, 1947–1978",
 "authorLine":"Agent run s8, 2026-10-30","introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":E}
json.dump(C,open("collection.fruscollection","w"),ensure_ascii=False,indent=1)
print("entries",len(E))
